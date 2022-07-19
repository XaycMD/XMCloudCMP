Write-Host "Down containers..." -ForegroundColor Green
try {
  docker-compose --env-file ".env.user" down
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Container down failed, see errors above."
  }
}
finally {
}
