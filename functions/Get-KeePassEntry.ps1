function Get-KeePassEntry
{
    <#
        .SYNOPSIS
            Function to get keepass database entries.
        .DESCRIPTION
            This Funciton gets all keepass database entries or a specified group/folder subset if the -KeePassEntryGroupPath parameter is Specified.
        .PARAMETER KeePassEntryGroupPath
            Specify this parameter if you wish to only return entries form a specific folder path.
            Notes:
                * Path Separator is the forward slash character '/'
        .PARAMETER AsPlainText
            Specify this parameter if you want the KeePass database entries to be returns in plain text objects.
        .PARAMETER DatabaseProfileName
            *This Parameter is required in order to access your KeePass database.
            *This is a Dynamic Parameter that is populated from the KeePassConfiguration.xml.
                *You can generated this file by running the New-KeePassDatabaseConfiguration function.
        .PARAMETER MasterKey
            Specify a SecureString MasterKey if necessary to authenticat a keepass databse.
            If not provided and the database requires one you will be prompted for it.
            This parameter was created with scripting in mind.
        .PARAMETER AsPSCredential
            Output Entry as an PSCredential Object
        .EXAMPLE
            PS> Get-KeePassEntry -DatabaseProfileName TEST -AsPlainText

            This Example will return all enties in plain text format from that keepass database that was saved to the config with the name TEST.
        .EXAMPLE
            PS> Get-KeePassEntry -DatabaseProfileName TEST -KeePassEntryGroupPath 'General' -AsPlainText

            This Example will return all entries in plain text format from the General folder of the keepass database with the profile name TEST.
        .EXAMPLE
            PS> Get-KeePassEntry -DatabaseProfileName TEST -Title test -AsPSCredential

            This Example will return one entry as PSCredential Object
        .INPUTS
            String
        .OUTPUTS
            PSObject
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String] $KeePassEntryGroupPath,

        [Parameter(Position = 1)]
        [String] $Title,

        [Parameter(Position = 2)]
        [Switch] $AsPlainText,

        [Parameter(Position = 3)]
        [Alias('AsPSCredential')]
        [Switch] $WithCredential
    )
    dynamicparam
    {
        Get-KPDynamicParameters -DBProfilePosition 4 -MasterKeyPosition 5
    }
    begin
    {
        ## Get a list of all database profiles saved to the config xml.
        $DatabaseProfileList = (Get-KeePassDatabaseConfiguration).Name
        ## If no profiles exists do not return the parameter.
        if($DatabaseProfileList)
        {
            $DatabaseProfileName = $PSBoundParameters['DatabaseProfileName']
            $MasterKey = $PSBoundParameters['MasterKey']
            ## Open the database
            $KeePassConnectionObject = New-KPConnection -DatabaseProfileName $DatabaseProfileName -MasterKey $MasterKey
            ## remove any sensitive data
            if($MasterKey){Remove-Variable -Name MasterKey}
        }
        else
        {
            Write-Warning -Message '[BEGIN] There are Currently No Database Configuration Profiles.'
            Write-Warning -Message '[BEGIN] Please run the New-KeePassDatabaseConfiguration function before you use this function.'
            Throw 'There are Currently No Database Configuration Profiles.'
        }
    }
    process
    {
        if($KeePassEntryGroupPath)
        {
            ## Get All entries in the specified group
            $KeePassGroup = Get-KpGroup -KeePassConnection $KeePassConnectionObject -FullPath $KeePassEntryGroupPath
            if(-not $KeePassGroup)
            {
                Write-Warning -Message ('[PROCESS] The Specified KeePass Entry Group Path ({0}) does not exist.' -f $KeePassEntryGroupPath)
                Throw 'The Specified KeePass Entry Group Path ({0}) does not exist.' -f $KeePassEntryGroupPath
            }

            if($Title)
            {
                $ResultEntries = Get-KpEntry -KeePassConnection $KeePassConnectionObject -KeePassGroup $KeePassGroup -Title $Title
            }
            else
            {
                $ResultEntries = Get-KpEntry -KeePassConnection $KeePassConnectionObject -KeePassGroup $KeePassGroup
            }
        }
        else
        {
            ## Get all entries in all groups.
            if($Title)
            {
                $ResultEntries = Get-KPEntry -KeePassConnection $KeePassConnectionObject -Title $Title
            }
            else
            {
                $ResultEntries = Get-KPEntry -KeePassConnection $KeePassConnectionObject
            }
        }

        $ResultEntries | Add-Member -MemberType NoteProperty -Name 'DatabaseProfileName' -Value $DatabaseProfileName -PassThru | ConvertTo-KpPsObject -AsPlainText:$AsPlainText -WithCredential:$WithCredential
    }
    end
    {
        ## Clean up database connection
        Remove-KPConnection -KeePassConnection $KeePassConnectionObject
    }
}
