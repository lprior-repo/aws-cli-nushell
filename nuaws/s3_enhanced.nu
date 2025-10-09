# S3 Enhanced Features with Streaming Operations
# Memory-efficient S3 operations with streaming, multipart uploads, and lifecycle management

# ============================================================================
# Streaming S3 Operations
# ============================================================================

# Stream S3 objects with pagination and memory efficiency
export def "aws s3 list-objects-stream" [
    bucket: string,             # S3 bucket name
    --prefix(-p): string = "",  # Object prefix filter
    --max-keys(-m): int = 1000, # Maximum keys per page
    --delimiter(-d): string     # Delimiter for hierarchical listing
]: nothing -> any {
    generate {
        let mut continuation_token = ""
        let mut has_more = true
        
        while $has_more {
            let list_cmd = if ($continuation_token | is-empty) {
                $"aws s3api list-objects-v2 --bucket ($bucket) --prefix ($prefix) --max-keys ($max_keys)"
            } else {
                $"aws s3api list-objects-v2 --bucket ($bucket) --prefix ($prefix) --max-keys ($max_keys) --continuation-token ($continuation_token)"
            }
            
            let result = try {
                ^aws s3api list-objects-v2 --bucket $bucket --prefix $prefix --max-keys $max_keys --continuation-token $continuation_token | from json
            } catch { |err|
                print $"Error listing objects: ($err.msg)"
                break
            }
            
            # Yield current page
            if "Contents" in ($result | columns) {
                yield {
                    objects: $result.Contents,
                    bucket: $bucket,
                    prefix: $prefix,
                    page_token: $continuation_token,
                    is_truncated: ($result.IsTruncated? | default false)
                }
            }
            
            # Update continuation state
            $continuation_token = ($result.NextContinuationToken? | default "")
            $has_more = ($result.IsTruncated? | default false) and ($continuation_token | is-not-empty)
        }
    }
}

# Stream S3 object download with progress tracking
export def "aws s3 download-stream" [
    bucket: string,             # S3 bucket name
    key: string,               # S3 object key
    output_path: string,       # Local output path
    --chunk-size(-c): int = 8388608, # Chunk size in bytes (8MB default)
    --progress(-p)             # Show progress indicator
]: nothing -> record {
    let object_info = try {
        aws s3api head-object --bucket $bucket --key $key | from json
    } catch { |err|
        error make {
            msg: $"Failed to get object info: ($err.msg)",
            label: { text: "Object not accessible", span: (metadata $key).span }
        }
    }
    
    let total_size = $object_info.ContentLength
    let total_chunks = ($total_size / $chunk_size) + 1
    
    if $progress {
        print $"📥 Downloading ($key) - Size: ($total_size | into filesize) - Chunks: ($total_chunks)"
    }
    
    mut downloaded_bytes = 0
    mut chunk_number = 0
    
    # Create output file
    "" | save $output_path
    
    while $downloaded_bytes < $total_size {
        let range_start = $downloaded_bytes
        let range_end = ([$downloaded_bytes + $chunk_size - 1, $total_size - 1] | math min)
        let range = $"bytes=($range_start)-($range_end)"
        
        let chunk_data = try {
            aws s3api get-object --bucket $bucket --key $key --range $range --output-file /tmp/chunk.tmp
            open /tmp/chunk.tmp --raw
        } catch { |err|
            error make {
                msg: $"Failed to download chunk ($chunk_number): ($err.msg)",
                label: { text: "Chunk download failed", span: (metadata $key).span }
            }
        }
        
        # Append chunk to output file
        $chunk_data | save --append --raw $output_path
        
        $downloaded_bytes = $range_end + 1
        $chunk_number = $chunk_number + 1
        
        if $progress {
            let progress_pct = ($downloaded_bytes * 100 / $total_size)
            print $"  Progress: ($progress_pct | math round)% - Chunk ($chunk_number)/($total_chunks)"
        }
    }
    
    # Cleanup
    rm -f /tmp/chunk.tmp
    
    {
        bucket: $bucket,
        key: $key,
        output_path: $output_path,
        total_size: $total_size,
        chunks_downloaded: $chunk_number,
        download_completed: true,
        completed_at: (date now)
    }
}

# ============================================================================
# Multipart Upload Operations
# ============================================================================

# Automatic multipart upload for large files
export def "aws s3 upload-multipart" [
    local_path: string,         # Local file path
    bucket: string,             # S3 bucket name
    key: string,               # S3 object key
    --part-size(-s): int = 5242880, # Part size in bytes (5MB minimum)
    --max-concurrent(-c): int = 4,   # Maximum concurrent uploads
    --progress(-p)             # Show progress indicator
]: nothing -> record {
    # Validate input file
    if not ($local_path | path exists) {
        error make {
            msg: $"File not found: ($local_path)",
            label: { text: "Input file missing", span: (metadata $local_path).span }
        }
    }
    
    let file_size = (ls $local_path | get size | first)
    let total_parts = ($file_size / $part_size) + 1
    
    if $progress {
        print $"📤 Uploading ($local_path) - Size: ($file_size | into filesize) - Parts: ($total_parts)"
    }
    
    # Initiate multipart upload
    let upload_init = try {
        aws s3api create-multipart-upload --bucket $bucket --key $key | from json
    } catch { |err|
        error make {
            msg: $"Failed to initiate multipart upload: ($err.msg)",
            label: { text: "Upload initialization failed", span: (metadata $bucket).span }
        }
    }
    
    let upload_id = $upload_init.UploadId
    
    if $progress {
        print $"  Upload ID: ($upload_id)"
    }
    
    # Upload parts in parallel batches
    let parts = 0..<$total_parts | each { |part_num|
        let part_start = $part_num * $part_size
        let part_end = ([$part_start + $part_size, $file_size] | math min)
        
        {
            part_number: ($part_num + 1),
            start_byte: $part_start,
            end_byte: $part_end,
            size: ($part_end - $part_start)
        }
    }
    
    let uploaded_parts = []
    
    # Process parts in concurrent batches
    for batch in ($parts | group --by { |item, index| $index mod $max_concurrent } | transpose key value) {
        let batch_results = $batch.value | par-each { |part|
            upload-single-part $local_path $bucket $key $upload_id $part $progress
        }
        
        $uploaded_parts | append $batch_results
    }
    
    # Complete multipart upload
    let parts_xml = create-parts-xml $uploaded_parts
    
    let completion_result = try {
        echo $parts_xml | aws s3api complete-multipart-upload --bucket $bucket --key $key --upload-id $upload_id --multipart-upload file:///dev/stdin | from json
    } catch { |err|
        # Abort upload on failure
        aws s3api abort-multipart-upload --bucket $bucket --key $key --upload-id $upload_id
        error make {
            msg: $"Failed to complete multipart upload: ($err.msg)",
            label: { text: "Upload completion failed", span: (metadata $key).span }
        }
    }
    
    {
        bucket: $bucket,
        key: $key,
        local_path: $local_path,
        upload_id: $upload_id,
        total_parts: $total_parts,
        file_size: $file_size,
        etag: $completion_result.ETag,
        location: $completion_result.Location,
        upload_completed: true,
        completed_at: (date now)
    }
}

# Upload single part for multipart upload
def upload-single-part [
    local_path: string,
    bucket: string,
    key: string,
    upload_id: string,
    part: record,
    show_progress: bool
]: nothing -> record {
    # Extract part data
    let part_data = try {
        open $local_path --raw | bytes at $part.start_byte..$part.end_byte
    } catch { |err|
        error make {
            msg: $"Failed to read part ($part.part_number): ($err.msg)",
            label: { text: "Part data extraction failed", span: (metadata $local_path).span }
        }
    }
    
    # Save part to temporary file
    let temp_file = $"/tmp/part_($part.part_number).tmp"
    $part_data | save --raw $temp_file
    
    # Upload part
    let upload_result = try {
        aws s3api upload-part --bucket $bucket --key $key --upload-id $upload_id --part-number $part.part_number --body $temp_file | from json
    } catch { |err|
        rm -f $temp_file
        error make {
            msg: $"Failed to upload part ($part.part_number): ($err.msg)",
            label: { text: "Part upload failed", span: (metadata $key).span }
        }
    }
    
    # Cleanup temp file
    rm -f $temp_file
    
    if $show_progress {
        print $"    Part ($part.part_number)/? uploaded - ETag: ($upload_result.ETag)"
    }
    
    {
        part_number: $part.part_number,
        etag: $upload_result.ETag,
        size: $part.size
    }
}

# Create XML for completing multipart upload
def create-parts-xml [parts: list<record>]: nothing -> string {
    let parts_xml = $parts | each { |part|
        $"    <Part>
        <PartNumber>($part.part_number)</PartNumber>
        <ETag>($part.etag)</ETag>
    </Part>"
    } | str join "\n"
    
    $"<CompleteMultipartUpload>
($parts_xml)
</CompleteMultipartUpload>"
}

# ============================================================================
# Presigned URL Generation
# ============================================================================

# Generate presigned URLs with configurable expiration
export def "aws s3 presign-url" [
    bucket: string,             # S3 bucket name
    key: string,               # S3 object key
    --operation(-o): string = "get", # Operation (get, put, delete)
    --expires(-e): duration = 1hr,   # URL expiration time
    --content-type(-t): string  # Content type for PUT operations
]: nothing -> record {
    let expires_seconds = ($expires | into int) / 1_000_000_000
    
    let presign_cmd = match $operation {
        "get" => $"aws s3 presign s3://($bucket)/($key) --expires-in ($expires_seconds)",
        "put" => {
            if ($content_type | is-empty) {
                $"aws s3api generate-presigned-url --bucket ($bucket) --key ($key) --http-method PUT --expires-in ($expires_seconds)"
            } else {
                $"aws s3api generate-presigned-url --bucket ($bucket) --key ($key) --http-method PUT --expires-in ($expires_seconds) --content-type ($content_type)"
            }
        },
        "delete" => $"aws s3api generate-presigned-url --bucket ($bucket) --key ($key) --http-method DELETE --expires-in ($expires_seconds)",
        _ => {
            error make {
                msg: $"Unsupported operation: ($operation). Use 'get', 'put', or 'delete'",
                label: { text: "Invalid operation", span: (metadata $operation).span }
            }
        }
    }
    
    let presigned_url = try {
        bash -c $presign_cmd | str trim
    } catch { |err|
        error make {
            msg: $"Failed to generate presigned URL: ($err.msg)",
            label: { text: "Presign operation failed", span: (metadata $bucket).span }
        }
    }
    
    {
        bucket: $bucket,
        key: $key,
        operation: $operation,
        url: $presigned_url,
        expires_in: $expires,
        expires_at: ((date now) + $expires),
        content_type: ($content_type | default ""),
        generated_at: (date now)
    }
}

# ============================================================================
# S3 Lifecycle Policy Management
# ============================================================================

# Create and manage S3 lifecycle policies
export def "aws s3 lifecycle create" [
    bucket: string,             # S3 bucket name
    rule_id: string,           # Lifecycle rule ID
    --prefix(-p): string = "",  # Object prefix filter
    --transition-days(-t): int, # Days before transition
    --storage-class(-s): string = "STANDARD_IA", # Target storage class
    --expiration(-e): int      # Days before expiration (optional)
]: nothing -> record {
    let lifecycle_rule = {
        ID: $rule_id,
        Status: "Enabled",
        Filter: {
            Prefix: $prefix
        },
        Transitions: [
            {
                Days: $transition_days,
                StorageClass: $storage_class
            }
        ]
    }
    
    # Add expiration if specified
    let rule_with_expiration = if ($expiration | is-not-empty) {
        $lifecycle_rule | upsert Expiration { Days: $expiration }
    } else {
        $lifecycle_rule
    }
    
    let lifecycle_config = {
        Rules: [$rule_with_expiration]
    }
    
    # Apply lifecycle configuration
    let result = try {
        $lifecycle_config | to json | aws s3api put-bucket-lifecycle-configuration --bucket $bucket --lifecycle-configuration file:///dev/stdin
    } catch { |err|
        error make {
            msg: $"Failed to create lifecycle policy: ($err.msg)",
            label: { text: "Lifecycle policy creation failed", span: (metadata $bucket).span }
        }
    }
    
    {
        bucket: $bucket,
        rule_id: $rule_id,
        prefix: $prefix,
        transition_days: $transition_days,
        storage_class: $storage_class,
        expiration_days: ($expiration | default null),
        policy_created: true,
        created_at: (date now)
    }
}

# ============================================================================
# Storage Cost Analysis
# ============================================================================

# Analyze S3 storage costs and provide optimization recommendations
export def "aws s3 analyze-costs" [
    bucket: string,             # S3 bucket name
    --detailed(-d)             # Include detailed analysis
]: nothing -> record {
    # Get bucket metrics
    let objects_info = try {
        aws s3api list-objects-v2 --bucket $bucket | from json
    } catch { |err|
        error make {
            msg: $"Failed to analyze bucket: ($err.msg)",
            label: { text: "Bucket analysis failed", span: (metadata $bucket).span }
        }
    }
    
    if "Contents" not-in ($objects_info | columns) {
        return {
            bucket: $bucket,
            total_objects: 0,
            total_size: 0,
            analysis: "Bucket is empty",
            recommendations: []
        }
    }
    
    let objects = $objects_info.Contents
    let total_objects = ($objects | length)
    let total_size = ($objects | get Size | math sum)
    
    # Analyze object age distribution
    let now = (date now)
    let age_analysis = $objects | each { |obj|
        let age_days = (($now - ($obj.LastModified | into datetime)) / 1day)
        {
            key: $obj.Key,
            size: $obj.Size,
            age_days: $age_days,
            storage_class: ($obj.StorageClass? | default "STANDARD")
        }
    }
    
    # Generate storage class recommendations
    let old_objects = $age_analysis | where age_days > 30
    let very_old_objects = $age_analysis | where age_days > 90
    
    let recommendations = []
    
    if ($old_objects | length) > 0 {
        let potential_ia_savings = ($old_objects | get size | math sum)
        $recommendations | append $"Move ($old_objects | length) objects (($potential_ia_savings | into filesize)) to STANDARD_IA after 30 days"
    }
    
    if ($very_old_objects | length) > 0 {
        let potential_glacier_savings = ($very_old_objects | get size | math sum)
        $recommendations | append $"Move ($very_old_objects | length) objects (($potential_glacier_savings | into filesize)) to GLACIER after 90 days"
    }
    
    let size_distribution = $age_analysis | group-by storage_class | transpose key value | each { |item|
        {
            storage_class: $item.key,
            object_count: ($item.value | length),
            total_size: ($item.value | get size | math sum)
        }
    }
    
    {
        bucket: $bucket,
        total_objects: $total_objects,
        total_size: $total_size,
        size_distribution: $size_distribution,
        recommendations: $recommendations,
        potential_savings: {
            ia_transition: ($old_objects | get size | math sum),
            glacier_transition: ($very_old_objects | get size | math sum)
        },
        analyzed_at: (date now)
    }
}