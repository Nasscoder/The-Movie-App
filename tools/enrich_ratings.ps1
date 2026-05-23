$ErrorActionPreference = "Stop"

$tmdbApiKey = "b03a69657e3c54faa142f4d68b378b34"
$tmdbBaseUrl = "https://api.themoviedb.org/3"
$jsonPath = Join-Path $PWD "assets\library_seed.json"

if (-not (Test-Path $jsonPath)) {
    Write-Host "Error: assets\library_seed.json not found."
    exit 1
}

Write-Host "Reading library_seed.json..."
$jsonContent = Get-Content -Raw -Encoding UTF8 $jsonPath
$mediaList = ConvertFrom-Json -InputObject $jsonContent

Write-Host "Fetching age ratings for $($mediaList.Count) items from TMDB..."
$updatedCount = 0

for ($i = 0; $i -lt $mediaList.Count; $i++) {
    $item = $mediaList[$i]
    
    # If age_rating exists and is not null/empty, skip
    $hasProp = Get-Member -InputObject $item -Name "age_rating" -MemberType Properties
    if ($hasProp -and $item.age_rating) {
        continue
    }

    $id = $item.id
    $type = $item.type
    $title = $item.title
    $ageRating = $null

    try {
        if ($type -eq "movie") {
            $url = "$tmdbBaseUrl/movie/$id/release_dates?api_key=$tmdbApiKey"
            $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction SilentlyContinue
            if ($response -and $response.results) {
                foreach ($r in $response.results) {
                    if ($r.iso_3166_1 -eq 'US') {
                        foreach ($rd in $r.release_dates) {
                            if ($rd.certification) {
                                $ageRating = $rd.certification
                                break
                            }
                        }
                    }
                    if ($ageRating) { break }
                }
            }
        } elseif ($type -eq "tv") {
            $url = "$tmdbBaseUrl/tv/$id/content_ratings?api_key=$tmdbApiKey"
            $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction SilentlyContinue
            if ($response -and $response.results) {
                foreach ($r in $response.results) {
                    if ($r.iso_3166_1 -eq 'US') {
                        $ageRating = $r.rating
                        break
                    }
                }
            }
        }
    } catch {
        Write-Host "Error fetching rating for ${title}: $_"
    }

    if (-not $ageRating) {
        if ($type -eq 'tv') {
            # Basic fallback
            $ageRating = 'TV-14'
        } else {
            $ageRating = 'PG-13'
        }
        Write-Host "  -> [$i/$($mediaList.Count)] ${title}: Defaulted to $ageRating"
    } else {
        Write-Host "  -> [$i/$($mediaList.Count)] ${title}: Found $ageRating"
        $updatedCount++
    }

    Add-Member -InputObject $item -MemberType NoteProperty -Name "age_rating" -Value $ageRating -Force

    Start-Sleep -Milliseconds 100
}

Write-Host "Writing updated JSON back to file..."
$mediaList | ConvertTo-Json -Depth 100 | Set-Content -Path $jsonPath -Encoding UTF8

Write-Host "Successfully enriched $updatedCount items with age ratings!"
