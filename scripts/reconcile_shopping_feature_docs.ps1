param(
  [string]$OutputPath = (Join-Path $PSScriptRoot '..\docs\shopping-feature-compendium.md')
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$paths = @(
  'lib/ui/features/shopping/pages/smart_shopping_list_page.dart',
  'lib/ui/features/shopping/pages/shopping_page.dart',
  'lib/ui/features/shopping/widgets/shopping_list_item_tile.dart',
  'lib/ui/features/shopping/widgets/shopping_add_dialog.dart',
  'lib/ui/features/shopping/widgets/shopping_add_product_dialog.dart',
  'lib/cubits/shopping_cubit.dart',
  'lib/cubits/shopping_state.dart',
  'lib/repositories/grocery_repository.dart',
  'lib/services/shopping_products_service.dart',
  'lib/services/widget_service.dart',
  'lib/services/firestore_sync_service.dart',
  'lib/main.dart',
  'lib/home_screen.dart',
  'docs/ui.md',
  'docs/cubits.md',
  'docs/models.md',
  'android/app/src/main/java/com/kianhamidi/housekeepr/ShoppingListWidget.kt',
  'android/app/src/main/java/com/kianhamidi/housekeepr/ShoppingListRemoteViewsFactory.kt',
  'android/app/src/main/java/com/kianhamidi/housekeepr/ShoppingListRemoteViewsService.kt'
)

function Get-RelativeLink {
  param([string]$Path)

  return ($Path -replace '\\', '/')
}

$builder = New-Object System.Text.StringBuilder

[void]$builder.AppendLine('# Shopping Feature Compendium')
[void]$builder.AppendLine()
[void]$builder.AppendLine('Generated from the shopping/cart/list feature files in this repository.')
[void]$builder.AppendLine()
[void]$builder.AppendLine('## Included Files')

foreach ($path in $paths) {
  [void]$builder.AppendLine("- [$(Get-RelativeLink $path)]($(Get-RelativeLink $path))")
}

[void]$builder.AppendLine()

foreach ($path in $paths) {
  $fullPath = Join-Path $repoRoot $path
  if (-not (Test-Path $fullPath)) {
    throw "Missing file: $path"
  }

  $relativeLink = Get-RelativeLink $path
  $extension = [IO.Path]::GetExtension($path).TrimStart('.').ToLowerInvariant()
  if ($extension -eq 'kt') {
    $extension = 'kotlin'
  } elseif ([string]::IsNullOrWhiteSpace($extension)) {
    $extension = 'text'
  }

  $fence = '````'

  [void]$builder.AppendLine("## $path")
  [void]$builder.AppendLine()
  [void]$builder.AppendLine("[Open source file]($relativeLink)")
  [void]$builder.AppendLine()
  [void]$builder.AppendLine($fence + $extension)
  [void]$builder.AppendLine((Get-Content -Raw -Path $fullPath))
  [void]$builder.AppendLine($fence)
  [void]$builder.AppendLine()
}

$outputDir = Split-Path -Parent $OutputPath
if ($outputDir -and -not (Test-Path $outputDir)) {
  New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

Set-Content -Path $OutputPath -Value $builder.ToString() -Encoding UTF8

Write-Host "Wrote combined shopping feature markdown to $OutputPath"