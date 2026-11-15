# Send-ModuleReleaseApproval.ps1
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [PSCustomObject]$AstReviewResult,
    [Parameter(Mandatory)] [string]$TeamId,
    [Parameter(Mandatory)] [string]$ChannelId,
    [Parameter()] [string]$ReleaseAuditSiteId = '',
    [Parameter()] [string]$ReleaseAuditListId = '',
    [Parameter()] [scriptblock]$GraphInvoker = $null
)

$ErrorActionPreference = 'Stop'

function Invoke-GraphReleaseApi {
    param([string]$Method, [string]$Uri, [hashtable]$Body)
    if ($null -ne $GraphInvoker) {
        return & $GraphInvoker $Method $Uri $Body
    }
    return Invoke-MgGraphRequest -Method $Method -Uri $Uri -Body ($Body | ConvertTo-Json -Depth 12) -ContentType 'application/json'
}

if ($AstReviewResult.Verdict -eq 'PERMIT_NON_BREAKING_RELEASE') {
    return [PSCustomObject]@{
        ApprovalCardSent = $false
        Reason           = 'Non-breaking release permitted automatically without dual-signature escalation.'
    }
}

$breakingList = if ($AstReviewResult.BreakingChanges.Count -gt 0) {
    ($AstReviewResult.BreakingChanges | ForEach-Object { "- $_" }) -join "`n"
} else {
    '- No AST breaking parameter changes detected.'
}

$migrationList = if ($AstReviewResult.MigrationNotes.Count -gt 0) {
    ($AstReviewResult.MigrationNotes | ForEach-Object { "- $_" }) -join "`n"
} else {
    '- Standard SemVer upgrade.'
}

$card = @{
    type    = 'AdaptiveCard'
    version = '1.5'
    body    = @(
        @{
            type   = 'TextBlock'
            text   = "Platform Module Release Gate: $($AstReviewResult.ModuleName) ($($AstReviewResult.PreviousVersion) -> $($AstReviewResult.CandidateVersion))"
            weight = 'Bolder'
            size   = 'Medium'
            color  = if ($AstReviewResult.Verdict -match 'REJECT') { 'Attention' } else { 'Warning' }
        },
        @{
            type  = 'FactSet'
            facts = @(
                @{ title = 'Verdict'; value = [string]$AstReviewResult.Verdict },
                @{ title = 'Requires Dual Signature'; value = [string]($AstReviewResult.Verdict -eq 'REQUIRE_DUAL_SIGNATURE_MAJOR_APPROVAL') },
                @{ title = 'AST Confidence'; value = [string]$AstReviewResult.Confidence }
            )
        },
        @{
            type = 'TextBlock'
            text = "Breaking Changes:`n$breakingList`n`nMigration Notes:`n$migrationList"
            wrap = $true
        }
    )
}

$attId = [guid]::NewGuid().ToString()
$payload = @{
    body        = @{ contentType = 'html'; content = "<attachment id=`"$attId`"></attachment>" }
    attachments = @(@{ id = $attId; contentType = 'application/vnd.microsoft.card.adaptive'; content = ($card | ConvertTo-Json -Depth 10 -Compress) })
}

$teamsUri = "https://graph.microsoft.com/v1.0/teams/$TeamId/channels/$ChannelId/messages"
$teamsResp = Invoke-GraphReleaseApi -Method 'POST' -Uri $teamsUri -Body $payload

$auditLogged = $false
if (-not [string]::IsNullOrWhiteSpace($ReleaseAuditSiteId) -and -not [string]::IsNullOrWhiteSpace($ReleaseAuditListId)) {
    $listUri = "https://graph.microsoft.com/v1.0/sites/$ReleaseAuditSiteId/lists/$ReleaseAuditListId/items"
    $null = Invoke-GraphReleaseApi -Method 'POST' -Uri $listUri -Body @{
        fields = @{
            Title            = "$($AstReviewResult.ModuleName) $($AstReviewResult.CandidateVersion)"
            Verdict          = [string]$AstReviewResult.Verdict
            PreviousVersion  = [string]$AstReviewResult.PreviousVersion
        }
    }
    $auditLogged = $true
}

return [PSCustomObject]@{
    ApprovalCardSent = $true
    TeamsEndpoint    = $teamsUri
    TeamsMessageId   = $teamsResp.id
    SharePointLogged = $auditLogged
    Verdict          = $AstReviewResult.Verdict
}
