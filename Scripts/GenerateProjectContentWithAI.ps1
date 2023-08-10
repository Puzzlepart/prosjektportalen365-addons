Param(
    [Parameter(Mandatory = $true)][string]$Url
)

function ConvertPSObjectToHashtable {
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process {
        if ($null -eq $InputObject) { return $null }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @(
                foreach ($object in $InputObject) { ConvertPSObjectToHashtable $object }
            )

            Write-Output -NoEnumerate $collection
        }
        elseif ($InputObject -is [psobject]) {
            $hash = @{}

            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertPSObjectToHashtable $property.Value
            }

            $hash
        }
        else {
            $InputObject
        }
    }
}
if ($null -eq (Get-Command Set-PnPTraceLog -ErrorAction SilentlyContinue)) {
    Write-Host "You have to load the PnP.PowerShell module before running this script!" -ForegroundColor Red
    exit 0
}
if ($null -eq (Get-Command Get-GPT3Completion -ErrorAction SilentlyContinue)) {
    Write-Host "You have to load the PowerShellAI module before running this script!" -ForegroundColor Red
    exit 0
}
if ($null -eq $env:OpenAIKey) {
    Write-Host "You have to set the OpenAIKey environment variable (`$env:OpenAIKey`) before running this script!" -ForegroundColor Red
    exit 0
}

$ErrorActionPreference = "Stop"
Set-PnPTraceLog -Off

Connect-PnPOnline -Url $Url -Interactive

$Site = Get-PnPSite
$Web = Get-PnPWeb
$SiteTitle = $Web.Title

$ctx = Get-PnPContext
$ctx.Load($ctx.Web.CurrentUser)
$ctx.ExecuteQuery()
$CurrentUserEmail = $ctx.Web.CurrentUser.Email

$TargetLists = @(
    @{Name="Interessentregister"; Max=7},
    @{Name="Prosjektleveranser"; Max=4},
    @{Name="Kommunikasjonsplan"; Max=7},
    @{Name="Prosjektlogg"; Max=6},
    @{Name="Usikkerhet"; Max=7},
    @{Name="Endringsanalyse"; Max=3},
    @{Name="Gevinstanalyse og gevinstrealiseringsplan"; Max=6},
    @{Name="Måleindikatorer"; Max=6},
    @{Name="Gevinstoppfølging"; Max=7}
)

Write-Host "Script ready to generate demo content with AI in site '$SiteTitle'"

$TargetLists | ForEach-Object {
    $ListTitle = $_["Name"]
    $PromptMaxElements = $_["Max"]
    
    Write-Host "Processing list '$ListTitle'. Generating prompt..."

    $Fields = Get-PnPField -List $ListTitle | Where-Object { $_.InternalName -eq "Title" -or $_.InternalName.StartsWith("Gt") }

    $FieldPrompt = ""
    $Fields | ForEach-Object { 
        $FieldPromptValue =  "'$($_.Title)' (Internt navn '$($_.InternalName)'"
        if ($_.Description) {
            $FieldPromptValue += ", beskrivelse av input: '$($_.Description)'"
        }

        if ($_.TypeAsString -eq "DateTime") {
            $FieldPromptValue += ", datoformat: yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fffffff"
        }  elseif ($_.TypeAsString -eq "Number") {
            $FieldPromptValue += ", verdien skal være et heltall"
        } elseif ($_.TypeAsString -eq "User" -or $_.TypeAsString -eq "UserMulti") {
            $FieldPromptValue += ", verdi skal være '$CurrentUserEmail'"
        } elseif ($_.TypeAsString -eq "Choice" -or $_.TypeAsString -eq "MultiChoice") {
            if ($_.Choices) {
                $FieldPromptValue += ", valg: '$($_.Choices -join ", ")'"
            }
        } elseif (($_.TypeAsString -eq "Lookup" -or $_.TypeAsString -eq "LookupMulti")) {
            if ($_.InternalName.Contains("_")) {
                return
            }
            [array]$LookupChoicesListItems = Get-PnPListItem -List $_.LookupList
            if ($LookupChoicesListItems.Count -lt 1) {
                return
            }
            if ($_.TypeAsString -eq "LookupMulti") {
                $LookupChoices = ", valg (bruk ID-verdien til en eller flere av de følgende (ID kommaseparert, f.eks. 1,23,30)): "
            } else {
                $LookupChoices = ", valg (bruk ID-verdien til en av følgende): "
            }
            $LookupChoicesListItems | ForEach-Object {
                $LookupChoices += "$($_.FieldValues.Title) (ID: $($_.FieldValues.ID)), "
            }
            $LookupChoices = $LookupChoices.TrimEnd(", ")
            $FieldPromptValue += $LookupChoices
        } elseif ($_.TypeAsString -eq "TaxonomyFieldType" -or $_.TypeAsString -eq "TaxonomyFieldTypeMulti") {
            $termGroup = Get-PnPTermGroup -Identity "Prosjektportalen"
            if ($null -ne $termGroup) {
                $termSet = Get-PnPTermSet -Identity $_.TermSetId.Guid -TermGroup $termGroup.Id.Guid
                $terms = Get-PnPTerm -TermSet $termSet -TermGroup $termGroup.Id.Guid

                $LookupChoices = ", valg (bruk ID-verdien til en av følgende): "
                
                $terms | ForEach-Object {
                    $LookupChoices += "$($_.Name) (ID: $($_.Id)), "
                }
                $LookupChoices = $LookupChoices.TrimEnd(", ")
                $FieldPromptValue += $LookupChoices
            }
        } elseif ($_.TypeAsString -eq "Calculated") {
            return
        }elseif ($_.TypeAsString -eq "Boolean") {
            return
        }

        $FieldPromptValue += "), "
        $FieldPrompt += $FieldPromptValue
    }
    $FieldPrompt = $FieldPrompt.TrimEnd(", ")

    $Prompt = "Gi meg maks $PromptMaxElements eksempler på $ListTitle for et prosjekt som heter '$SiteTitle'. VIKTIG: Lengden på returnert JSON-tabell må ikke være på flere enn 2048 tegn. Feltene til listen er følgende: $FieldPrompt. Verdien i tittel-feltet skal være unikt, det skal si noe om hva oppføringen handler om, og skal ikke være det samme som prosjektnavnet. Returner elementene som en ren json array. Bruk internnavnene på feltene i JSON-objektet. "
    
    Write-Host "Prompt ready. Asking for suggestions from GPT3..."
    $AIResults = Get-GPT3Completion -prompt $Prompt -max_tokens 2048 -temperature 0.3

    try {
        $TestJsonResult = Test-Json -Json $AIResults
    } catch {
        Write-Host "The AI did not return valid JSON." -ForegroundColor Red
        Write-Host $Prompt
        Write-Host $AIResults
        exit 0
    }

    $AIGeneratedItems = ConvertFrom-Json ($AIResults.Trim())


    $AIGeneratedItems | ForEach-Object {
        Write-Host "`tCreating list item '$($_.Title)' for list '$ListTitle'"
        $HashtableValues = ConvertPSObjectToHashtable -InputObject $_
        @($HashtableValues.keys) | ForEach-Object { 
            if (-not $HashtableValues[$_]) { $HashtableValues.Remove($_) } 
        }
        try {
            $ItemResult = Add-PnPListItem -List $ListTitle -Values $HashtableValues
        } catch {
            Write-Host "Failed to create list item for list '$ListTitle'" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            Write-Host "Using the following prompt: $Prompt"
            Write-Host "Using the following AI generated:"
            $HashtableValues
        }
    }
}