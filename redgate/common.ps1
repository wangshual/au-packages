param(
    [string] $name,
    [string] $alternateName
)

if (-not ($alternateName)) {
    $alternateName = $name
}

import-module au

function global:au_SearchReplace {
    $d = [DateTimeOffset] $Latest.LastModified
    @{
        'tools\chocolateyInstall.ps1' = @{
            "(^[$]secondaryDownloadUrl\s*=\s*)(['`"].*['`"])"      = "`$1'$($Latest.URL32)'"
            "(^[$]checksum\s*=\s*)('.*')" = "`$1'$($Latest.Checksum32)'"
            # $packageVersionLastModified = New-Object -TypeName DateTimeOffset 2017, 7, 3, 11, 5, 0, 0 # Last modified time corresponding to this package version
            "(^[$]packageVersionLastModified\s*=\s*)(.*)(\s+\#)" = "`$1New-Object -TypeName DateTimeOffset $($d.Year), $($d.Month), $($d.Day), $($d.Hour), $($d.Minute), $($d.Second), 0`$3"
        }
    }
}

function global:au_GetLatest {

    try {
        # Get last modified from web download
        Write-Verbose "Get last modified from https://download.red-gate.com/$name.exe"
        $response = Invoke-WebRequest "https://download.red-gate.com/$name.exe" -Method Head
        $lastModifiedHeader = $response.Headers.'Last-Modified'
        $lastModified = [DateTimeOffset]::Parse($lastModifiedHeader, [Globalization.CultureInfo]::InvariantCulture)

        # Infer what the FTP download should be and grab that to find out the version (and indirectly confirm that the URL is correct)
        # $secondaryDownloadUrl = "ftp://support.red-gate.com/patches/SQLToolbelt/03Jul2017/SQLToolbelt.exe"
        $secondaryDownloadUrl = "ftp://support.red-gate.com/patches/$alternateName/$($lastModified.ToString("ddMMMyyyy"))/$alternateName.exe"

        $downloadedFile = [IO.Path]::GetTempFileName()

        Write-Verbose "Downloading $secondaryDownloadUrl"
        try {
            
            $client = new-object System.Net.WebClient
            $client.DownloadFile($secondaryDownloadUrl, $downloadedFile)

            # SqlSearch has strange FileVersion, so use FileVersionRaw as that seems correct
            $version = (get-item $downloadedFile).VersionInfo.FileVersionRaw
            Write-Verbose "$version"
            $checksum = (Get-FileHash $downloadedFile -Algorithm SHA256).Hash
            Write-Verbose "$checksum"

            Remove-Item $downloadedFile

            $Latest = @{ 
                URL32 = $secondaryDownloadUrl
                Version = $version
                Checksum32 = $checksum
                LastModified = $lastModified
            }
        }
        catch {
            Write-Warning "Could not find file $secondaryDownloadUrl"
            $Latest = 'ignore'
        }
    } catch {
        Write-Error $_

        $Latest = 'ignore'
    }
     
    return $Latest
}

update -ChecksumFor none