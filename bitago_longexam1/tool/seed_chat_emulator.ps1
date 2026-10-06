# Seeds only the local demo emulator, never the real Firebase project.
$ErrorActionPreference = 'Stop'
foreach ($name in @('alice', 'bob')) {
  $payload = @{ email = "$name@example.com"; password = 'DemoChat2026!'; returnSecureToken = $true } | ConvertTo-Json
  try {
    $account = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-key' -ContentType 'application/json' -Body $payload
  } catch {
    $account = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key' -ContentType 'application/json' -Body $payload
  }
  $fields = @{
    fName = @{stringValue = (Get-Culture).TextInfo.ToTitleCase($name)}
    lName = @{stringValue = 'Chat Test'}
    emailAddress = @{stringValue = "$name@example.com"}
    username = @{stringValue = "${name}_demo"}
    age = @{integerValue = '22'}
    contactNo = @{stringValue = '0000000000'}
  }
  $body = @{fields = $fields} | ConvertTo-Json -Depth 5
  $headers = @{Authorization = "Bearer $($account.idToken)"}
  $null = Invoke-RestMethod -Method Patch -Uri "http://127.0.0.1:8088/v1/projects/demo-bitago/databases/(default)/documents/users/$($account.localId)" -Headers $headers -ContentType 'application/json' -Body $body
  Write-Output "Local test user ready: $name@example.com"
}
