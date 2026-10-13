$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$assetDir = Join-Path $projectRoot 'assets\images\online'
New-Item -ItemType Directory -Force -Path $assetDir | Out-Null

$images = @{
  'concert.jpg'     = 'https://commons.wikimedia.org/wiki/Special:FilePath/A_large_crowd_enjoys_a_music_concert_illuminated_by_colorful_lights_and_a_stunning_stage_display.jpg?width=1280'
  'cinema.jpg'      = 'https://commons.wikimedia.org/wiki/Special:FilePath/Cinema_theatre_screen.jpg?width=1280'
  'theatre.jpg'     = 'https://commons.wikimedia.org/wiki/Special:FilePath/Theatre_performance.jpg?width=1280'
  'sports.jpg'      = 'https://commons.wikimedia.org/wiki/Special:FilePath/Spectators_in_a_sports_stadium_observing_a_football_match1.jpg?width=1280'
  'workshop.jpg'    = 'https://commons.wikimedia.org/wiki/Special:FilePath/Wiki_Hackathon_2026_India_-_Coding_Session_-_IMG190.jpg?width=1280'
  'attraction.jpg'  = 'https://commons.wikimedia.org/wiki/Special:FilePath/Yokohama_Cosmo_World_and_Clock_Ferris_Wheel_(4611157059).jpg?width=1280'
  'experience.jpg'  = 'https://commons.wikimedia.org/wiki/Special:FilePath/Hikers_watching_sunrise_at_Mount_Pulag_summit.jpg?width=1280'
  'festival.jpg'    = 'https://commons.wikimedia.org/wiki/Special:FilePath/Traditional_street_food_market_for_ramadan_and_eid_festival.jpg?width=1280'
  'conference.jpg'  = 'https://commons.wikimedia.org/wiki/Special:FilePath/Lightning_Talks_Audiences.jpg?width=1280'
}

foreach ($item in $images.GetEnumerator()) {
  $out = Join-Path $assetDir $item.Key
  Write-Host "Downloading $($item.Key)..."
  Invoke-WebRequest -Uri $item.Value -OutFile $out -MaximumRedirection 10
}

Write-Host "Downloaded $($images.Count) real event images to $assetDir"
Write-Host 'Run: flutter pub get'
