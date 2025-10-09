# Enhanced S3 Tools for NuAWS
# Provides enhanced functionality on top of base S3 commands

# Export enhanced S3 commands
export def "s3 enhanced" [] {
    print "Enhanced S3 tools loaded successfully"
}

# Enhanced s3 ls with better formatting
export def "s3 ls-enhanced" [
    path?: string  # S3 path to list
    --recursive    # Recursive listing
] {
    if $recursive {
        ^aws s3 ls $path --recursive | lines | each { |line|
            let parts = ($line | parse "{date} {time} {size} {key}")
            if ($parts | length) > 0 {
                $parts | first
            }
        } | compact
    } else {
        ^aws s3 ls $path | lines | each { |line|
            let parts = ($line | parse "{date} {time} {size} {key}")
            if ($parts | length) > 0 {
                $parts | first
            }
        } | compact
    }
}

# Enhanced sync with progress
export def "s3 sync-enhanced" [
    source: string      # Source path
    destination: string # Destination path
    --delete           # Delete files not in source
] {
    let sync_args = if $delete { [--delete] } else { [] }
    ^aws s3 sync $source $destination ...$sync_args
}