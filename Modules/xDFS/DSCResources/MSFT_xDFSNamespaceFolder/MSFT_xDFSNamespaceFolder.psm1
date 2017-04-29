$script:ResourceRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent)

# Import the xCertificate Resource Module (to import the common modules)
Import-Module -Name (Join-Path -Path $script:ResourceRootPath -ChildPath 'xDFS.psd1')

# Import Localization Strings
$localizedData = Get-LocalizedData `
    -ResourceName 'MSFT_xDFSNamespaceFolder' `
    -ResourcePath (Split-Path -Parent $Script:MyInvocation.MyCommand.Path)

<#
    .SYNOPSIS
    Returns the current state of a DFS Namespace Folder.

    .PARAMETER Path
    Specifies a path for the root of a DFS namespace.

    .PARAMETER TargetPath
    Specifies a path for a root target of the DFS namespace.

    .PARAMETER Ensure
    Specifies if the DFS Namespace root should exist.
#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $TargetPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Present','Absent')]
        [System.String]
        $Ensure
    )

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.GettingNamespaceFolderMessage) `
                -f $Path,$TargetPath
        ) -join '' )

    # Generate the return object assuming absent.
    $returnValue = @{
        Path = $Path
        TargetPath = $TargetPath
        Ensure = 'Absent'
    }

    # Remove the Ensue parmeter from the bound parameters
    $null = $PSBoundParameters.Remove('Ensure')

    # Lookup the existing Namespace Folder
    $folder = Get-Folder `
        -Path $Path

    if ($folder)
    {
        # The namespace folder exists
        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.NamespaceFolderExistsMessage) `
                    -f $Path,$TargetPath
            ) -join '' )
    }
    else
    {
        # The namespace folder does not exist
        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.NamespaceFolderDoesNotExistMessage) `
                    -f $Path,$TargetPath
            ) -join '' )
        return $returnValue
    }

    $returnValue += @{
        TimeToLiveSec                = $folder.TimeToLiveSec
        State                        = $folder.State
        Description                  = $folder.Description
        EnableInsiteReferrals        = ($folder.Flags -contains 'Insite Referrals')
        EnableTargetFailback         = ($folder.Flags -contains 'Target Failback')
    }

    # DFS Folder exists but does target exist?
    $target = Get-FolderTarget `
        -Path $Path `
        -TargetPath $TargetPath

    if ($target)
    {
        # The target exists in this namespace
        $returnValue.Ensure = 'Present'
        $returnValue += @{
            ReferralPriorityClass        = $target.ReferralPriorityClass
            ReferralPriorityRank         = $target.ReferralPriorityRank
        }

        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.NamespaceFolderTargetExistsMessage) `
                    -f $Path,$TargetPath
            ) -join '' )
    }
    else
    {
        # The target does not exist in this namespace
        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.NamespaceFolderTargetDoesNotExistMessage) `
                    -f $Path,$TargetPath
            ) -join '' )
    }

    return $returnValue
} # Get-TargetResource

<#
    .SYNOPSIS
    Sets the current state of a DFS Namespace Folder.

    .PARAMETER Path
    Specifies a path for the root of a DFS namespace.

    .PARAMETER TargetPath
    Specifies a path for a root target of the DFS namespace.

    .PARAMETER Ensure
    Specifies if the DFS Namespace root should exist.

    .PARAMETER Description
    The description of the DFS Namespace.

    .PARAMETER TimeToLiveSec
    Specifies a TTL interval, in seconds, for referrals.

    .PARAMETER EnableInsiteReferrals
    Indicates whether a DFS namespace server provides a client only with referrals that are in the same site as the client.

    .PARAMETER EnableTargetFailback
    Indicates whether a DFS namespace uses target failback.

    .PARAMETER ReferralPriorityClass
    Specifies the target priority class for a DFS namespace root.

    .PARAMETER ReferralPriorityRank
    Specifies the priority rank, as an integer, for a root target of the DFS namespace.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $TargetPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Present','Absent')]
        [System.String]
        $Ensure,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.UInt32]
        $TimeToLiveSec,

        [Parameter()]
        [System.Boolean]
        $EnableInsiteReferrals,

        [Parameter()]
        [System.Boolean]
        $EnableTargetFailback,

        [Parameter()]
        [ValidateSet('Global-High','SiteCost-High','SiteCost-Normal','SiteCost-Low','Global-Low')]
        [System.String]
        $ReferralPriorityClass,

        [Parameter()]
        [System.UInt32]
        $ReferralPriorityRank
    )

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.SettingNamespaceFolderMessage) `
                -f $Path,$TargetPath
        ) -join '' )

    # Lookup the existing Namespace Folder
    $folder = Get-Folder `
        -Path $Path

    if ($Ensure -eq 'Present')
    {
        # Set desired Configuration
        if ($folder)
        {
            # Does the Folder need to be updated?
            [System.Boolean] $folderChange = $false

            # The Folder properties that will be updated
            $folderProperties = @{
                State = 'online'
            }

            if (($Description) `
                -and ($folder.Description -ne $Description))
            {
                $folderProperties += @{
                    Description = $Description
                }
                $folderChange = $true
            }

            if (($TimeToLiveSec) `
                -and ($folder.TimeToLiveSec -ne $TimeToLiveSec))
            {
                $folderProperties += @{
                    TimeToLiveSec = $TimeToLiveSec
                }
                $folderChange = $true
            }

            if (($null -ne $EnableInsiteReferrals) `
                -and (($folder.Flags -contains 'Insite Referrals') -ne $EnableInsiteReferrals))
            {
                $folderProperties += @{
                    EnableInsiteReferrals = $EnableInsiteReferrals
                }
                $folderChange = $true
            }

            if (($null -ne $EnableTargetFailback) `
                -and (($folder.Flags -contains 'Target Failback') -ne $EnableTargetFailback))
            {
                $folderProperties += @{
                    EnableTargetFailback = $EnableTargetFailback
                }
                $folderChange = $true
            }

            if ($folderChange)
            {
                # Update Folder settings
                $null = Set-DfsnFolder `
                    -Path $Path `
                    @FolderProperties `
                    -ErrorAction Stop

                $folderProperties.GetEnumerator() | ForEach-Object -Process {
                    Write-Verbose -Message ( @(
                        "$($MyInvocation.MyCommand): "
                        $($LocalizedData.NamespaceFolderUpdateParameterMessage) `
                            -f $Path,$TargetPath,$_.name, $_.value
                    ) -join '' )
                }
            }

            # Get target
            $target = Get-FolderTarget `
                -Path $Path `
                -TargetPath $TargetPath

            # Does the target need to be updated?
            [System.Boolean] $targetChange = $false

            # The Target properties that will be updated
            $targetProperties = @{}

            # Check the target properties
            if (($ReferralPriorityClass) `
                -and ($target.ReferralPriorityClass -ne $ReferralPriorityClass))
            {
                $targetProperties += @{
                    ReferralPriorityClass = ($ReferralPriorityClass -replace '-','')
                }
                $targetChange = $true
            }

            if (($ReferralPriorityRank) `
                -and ($target.ReferralPriorityRank -ne $ReferralPriorityRank))
            {
                $targetProperties += @{
                    ReferralPriorityRank = $ReferralPriorityRank
                }
                $targetChange = $true
            }

            # Is the target a member of the namespace?
            if ($target)
            {
                # Does the target need to be changed?
                if ($targetChange)
                {
                    # Update target settings
                    $null = Set-DfsnFolderTarget `
                        -Path $Path `
                        -TargetPath $TargetPath `
                        @TargetProperties `
                        -ErrorAction Stop
                }
            }
            else
            {
                # Add target to Namespace
                $null = New-DfsnFolderTarget `
                    -Path $Path `
                    -TargetPath $TargetPath `
                    @TargetProperties `
                    -ErrorAction Stop
            }

            # Output the target parameters that were changed/set
            $targetProperties.GetEnumerator() | ForEach-Object -Process {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceFolderTargetUpdateParameterMessage) `
                        -f $Path,$TargetPath,$_.name, $_.value
                ) -join '' )
            }
        }
        else
        {
            # Prepare to use the PSBoundParameters as a splat to created
            # The new DFS Namespace Folder.
            $null = $PSBoundParameters.Remove('Ensure')

            # Correct the ReferralPriorityClass field
            if ($ReferralPriorityClass)
            {
                $PSBoundParameters.ReferralPriorityClass = ($ReferralPriorityClass -replace '-','')
            }

            # Create New-DfsnFolder
            $null = New-DfsnFolder `
                @PSBoundParameters `
                -ErrorAction Stop

            $PSBoundParameters.GetEnumerator() | ForEach-Object -Process {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceFolderUpdateParameterMessage) `
                        -f $Path,$TargetPath,$_.name, $_.value
                ) -join '' )
            }
        }
    }
    else
    {
        # The Namespace Folder Target should not exist

        # Get Folder target
        $target = Get-FolderTarget `
            -Path $Path `
            -TargetPath $TargetPath

        if ($target)
        {
            # Remove the target from the Namespace Folder
            $null = Remove-DfsnFolderTarget `
                -Path $Path `
                -TargetPath $TargetPath `
                -Confirm:$false `
                -ErrorAction Stop

            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.NamespaceFolderTargetRemovedMessage) `
                    -f $Path,$TargetPath
            ) -join '' )
        }
    }
} # Set-TargetResource

<#
    .SYNOPSIS
    Tests the current state of a DFS Namespace Folder.

    .PARAMETER Path
    Specifies a path for the root of a DFS namespace.

    .PARAMETER TargetPath
    Specifies a path for a root target of the DFS namespace.

    .PARAMETER Ensure
    Specifies if the DFS Namespace root should exist.

    .PARAMETER Description
    The description of the DFS Namespace.

    .PARAMETER TimeToLiveSec
    Specifies a TTL interval, in seconds, for referrals.

    .PARAMETER EnableInsiteReferrals
    Indicates whether a DFS namespace server provides a client only with referrals that are in the same site as the client.

    .PARAMETER EnableTargetFailback
    Indicates whether a DFS namespace uses target failback.

    .PARAMETER ReferralPriorityClass
    Specifies the target priority class for a DFS namespace root.

    .PARAMETER ReferralPriorityRank
    Specifies the priority rank, as an integer, for a root target of the DFS namespace.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $TargetPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Present','Absent')]
        [System.String]
        $Ensure,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.UInt32]
        $TimeToLiveSec,

        [Parameter()]
        [System.Boolean]
        $EnableInsiteReferrals,

        [Parameter()]
        [System.Boolean]
        $EnableTargetFailback,

        [Parameter()]
        [ValidateSet('Global-High','SiteCost-High','SiteCost-Normal','SiteCost-Low','Global-Low')]
        [System.String]
        $ReferralPriorityClass,

        [Parameter()]
        [System.UInt32]
        $ReferralPriorityRank
    )

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.TestingNamespaceFolderMessage) `
                -f $Path,$TargetPath
        ) -join '' )

    # Flag to signal whether settings are correct
    [System.Boolean] $desiredConfigurationMatch = $true

    # Lookup the existing Namespace Folder
    $folder = Get-Folder `
        -Path $Path

    if ($Ensure -eq 'Present')
    {
        # The Namespace Folder should exist
        if ($folder)
        {
            # The Namespace Folder exists and should

            # Check the Namespace parameters
            if (($Description) `
                -and ($folder.Description -ne $Description)) {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceFolderParameterNeedsUpdateMessage) `
                        -f $Path,$TargetPath,'Description'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            if (($TimeToLiveSec) `
                -and ($folder.TimeToLiveSec -ne $TimeToLiveSec)) {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceFolderParameterNeedsUpdateMessage) `
                        -f $Path,$TargetPath,'TimeToLiveSec'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            if (($null -ne $EnableInsiteReferrals) `
                -and (($folder.Flags -contains 'Insite Referrals') -ne $EnableInsiteReferrals)) {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceFolderParameterNeedsUpdateMessage) `
                        -f $Path,$TargetPath,'EnableInsiteReferrals'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            if (($null -ne $EnableTargetFailback) `
                -and (($folder.Flags -contains 'Target Failback') -ne $EnableTargetFailback)) {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceFolderParameterNeedsUpdateMessage) `
                        -f $Path,$TargetPath,'EnableTargetFailback'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            $targe = Get-FolderTarget `
                -Path $Path `
                -TargetPath $TargetPath

            if ($targe)
            {
                if (($ReferralPriorityClass) `
                    -and ($targe.ReferralPriorityClass -ne $ReferralPriorityClass)) {
                    Write-Verbose -Message ( @(
                        "$($MyInvocation.MyCommand): "
                        $($LocalizedData.NamespaceFolderTargetParameterNeedsUpdateMessage) `
                            -f $Path,$TargetPath,'ReferralPriorityClass'
                        ) -join '' )
                    $desiredConfigurationMatch = $false
                }

                if (($ReferralPriorityRank) `
                    -and ($targe.ReferralPriorityRank -ne $ReferralPriorityRank)) {
                    Write-Verbose -Message ( @(
                        "$($MyInvocation.MyCommand): "
                        $($LocalizedData.NamespaceFolderTargetParameterNeedsUpdateMessage) `
                            -f $Path,$TargetPath,'ReferralPriorityRank'
                        ) -join '' )
                    $desiredConfigurationMatch = $false
                }
            }
            else
            {
                # The Folder target does not exist but should - change required
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceFolderTargetDoesNotExistButShouldMessage) `
                        -f $Path,$TargetPath
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }
        }
        else
        {
            # Ths Namespace Folder doesn't exist but should - change required
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                 $($LocalizedData.NamespaceFolderDoesNotExistButShouldMessage) `
                    -f $Path,$TargetPath
                ) -join '' )
            $desiredConfigurationMatch = $false
        }
    }
    else
    {
        # The Namespace target should not exist
        if ($folder)
        {
            $targe = Get-FolderTarget `
                -Path $Path `
                -TargetPath $TargetPath

            if ($targe)
            {
                # The Folder target exists but should not - change required
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceFolderTargetExistsButShouldNotMessage) `
                        -f $Path,$TargetPath
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }
            else
            {
                # The Namespace exists but the target doesn't - change not required
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceFolderTargetDoesNotExistAndShouldNotMessage) `
                        -f $Path,$TargetPath
                    ) -join '' )
            }
        }
        else
        {
            # The Namespace does not exist (so neither does the target) - change not required
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                 $($LocalizedData.NamespaceFolderDoesNotExistAndShouldNotMessage) `
                    -f $Path,$TargetPath
                ) -join '' )
        }
    } # if

    return $desiredConfigurationMatch

} # Test-TargetResource

<#
    .SYNOPSIS
    Lookup the DFSN Folder.

    .PARAMETER Path
    Specifies a path for the root of a DFS namespace.
#>
Function Get-Folder
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path
    )

    try
    {
        $dfsnFolder = Get-DfsnFolder `
            -Path $Path `
            -ErrorAction Stop
    }
    catch [Microsoft.Management.Infrastructure.CimException]
    {
        $dfsnFolder = $null
    }
    catch
    {
        Throw $_
    }
    Return $dfsnFolder
}

<#
    .SYNOPSIS
    Lookup the DFSN Folder Target in a namespace.

    .PARAMETER Path
    Specifies a path for the root of a DFS namespace.

    .PARAMETER TargetPath
    Specifies a path for a root target of the DFS namespace.
#>
Function Get-FolderTarget
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $TargetPath
    )

    try
    {
        $dfsnTarget = Get-DfsnFolderTarget `
            -Path $Path `
            -TargetPath $TargetPath `
            -ErrorAction Stop
    }
    catch [Microsoft.Management.Infrastructure.CimException]
    {
        $dfsnTarget = $null
    }
    catch
    {
        Throw $_
    }
    Return $dfsnTarget
}

Export-ModuleMember -Function *-TargetResource
