<#
.SYNOPSIS
It even checks for .SYNOPSIS blocks on .ps1 files!
#>
[CmdletBinding()]
param()

function Show-ModuleTree {
	<#
	.SYNOPSIS
	Returns a formatted tree
	#>
	param(
		[ValidateScript({
				Test-Path $_ -PathType Container
			})]
		# Directory that will be recursiveely searched, defaults to current dir
		[String]$Path = (Get-Location)
		,
		# If you just want a nice tree, but use tree.com at this point
		[Switch]$NoHyperlinks
		,
		[Int]$Indentation = 2 # The spacing at each level before the - bullet point
		,
		[Switch]$Force # Will also use -Force on Get-ChildItem to show hidden files
		,
		# Character used for bullet point, does not affect final rendered output
		[ValidateSet('-', '*')]
		[Char]$BulletChar = '-'
		,
		# Working hyperlink requires 
		[String]$RepoURL
		,
		# Where it starts linking, defaults to root (/)
		[String]$PathInRepo = [IO.Path]::DirectorySeparatorChar
		,
		# Use raw.githubusercontent for hyperlinks
		[Switch]$LinkRaw
		,
		# Branch of your repository to link
		[String]$Branch = "master"
		,
		# Files you wish to excluse from being put into the tree
		[String[]]$Exclude
	)

	$SEP = [IO.Path]::DirectorySeparatorChar

	if (!$RepoURL -and !$NoHyperlinks) {
		if ((Test-Path "$Path\.git") -and (Get-Command git -ErrorAction Ignore)) {
			Push-Location $Path
			$RepoURL = (git config remote.origin.url) -replace '^.+?/|\.git$' -replace "/github.com/", ""
			Pop-Location
		}
	}
 elseif ($RepoURL) {
		if ($RepoURL -like "*://gitlab.com/*") {
			throw "GitLab isn't supported yet, but feel free to PR!"
		}
		$RepoURL = ($RepoURL) -replace '^.+?/|\.git$' -replace "/github.com/", ""
	}

	$RepoBase = if ($LinkRaw) {
		"https://raw.githubusercontent.com/$RepoURL/$Branch/"
	}
	else {
		"https://github.com/$RepoURL/blob/$Branch/"
	}
	if ($PathInRepo -ne $SEP) {
		$RepoBase += $PathInRepo
	}

	function ConvertTo-AbstractSyntaxTree {
		<#
		Converts multi-line strings, scriptblocks, or filepaths to parseable ASTs
		#>
		[CmdletBinding()]
		[OutputType([System.Management.Automation.Language.ScriptBlockAst])]
		Param(
			[Parameter(ValueFromPipeline = $True)]
			$InputObject
		)
		Process {
			$Type = $InputObject.GetType().Name
			$Converted = switch ($Type) {
				FileInfo {
					# If it it is
					if (Get-Item $InputObject) {
						# If it already is a FileInfo
						(Get-Item $InputObject) # Return it as is
					}
				}
				String {
					# Either a filepath, function name or multi-line strinng

					if (Test-Path $InputObject) {
						# If it's the path to a string
						(Get-Item $InputObject) # Return it as FileInfo

					}
					elseif ($FuncObj = Get-Command -Name $InputObject -CommandType Function -ErrorAction Ignore) {
					
						[ScriptBlock]::Create((($FuncObj).ScriptBlock.Ast.Extent.Text))
						# Then it's a command, it's extent scriptblock is returned

					}
					elseif ($InputObject -Like "*`n*") {
						# Multi-line string get converted to scriptblocks
						
						[ScriptBlock]::Create(($InputObject))
					}
				}
				FunctionInfo {
					if ($AstText = [ScriptBlock]::Create((($InputObject).ScriptBlock.Ast.Extent.Text))) {
						
						$AstText
					}
					else {
						throw "Could not parse scriptblock from function `"$($InputObject.Name)`""
					}
				}
				ScriptBlock {
					# Already is a ScriptBlock
					$InputObject
				}
				default {
					# If an int, char or whatever else is passed
					throw "Could not find what to do with input of type `"$Type`""
				}
			}
			$Type = $Converted.GetType().Name
			$ret = switch ($Type) {
				ScriptBlock {
					[System.Management.Automation.Language.Parser]::ParseInput($Converted, [Ref]$Null, [Ref]$Null)
				}
				FileInfo {
					[System.Management.Automation.Language.Parser]::ParseFile($Converted, [Ref]$Null, [Ref]$Null)

				}
			}
			return $ret
		}
	}

	function Get-Synopsis {
		<#
		.SYNOPSIS
		Gets a function's synopsis
		#>
		[CmdletBinding()]
		param(
			$Function,
			$Path,
			$ScriptBlock
		)
		if ($Path) {
			if ((Get-Item $Path).Extension -notin '.ps1', '.psm1') {
				return $null
			}
			$AST = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)

		}
		elseif ($Function -or $ScriptBlock) {

			if ($Function -and !$ScriptBlock) {
				$ScriptBlock = [ScriptBlock]::Create(((Get-Command $Function).ScriptBlock.Ast.Extent.Text))
			}
			elseif ($ScriptBlock) {
				if ($Script -isnot [scriptblock]) {
					$ScriptBlock = [ScriptBlock]::Create($ScriptBlock)
				}
			}

			$AST = [System.Management.Automation.Language.Parser]::ParseInput($ScriptBlock, [ref]$null, [ref]$null)
		}
		$Definition = $AST.FindAll({
				param ($node)
				$node.GetType().Name -eq 'FunctionDefinitionAst'
			}, $true)

		if ($Definition) {
			return ($Definition  | Select-Object -First 1).GetHelpContent().Synopsis.Trim()
		}
		else {
			return $null
		}
	}


	function Get-Depth ($Path) {
		<#
		.SYNOPSIS
		Return how much directory separators are present
		#>
		$Path = (Get-Item $Path -Force).FullName.TrimEnd($SEP)
		$Count = ($Path.ToCharArray() | Where-Object { $_ -eq $SEP }).Count
		Write-Verbose "$Path has $Count slashes"
		return $Count
	}

	function Get-ScriptDeclarations {
		<#
		.SYNOPSIS
		Parse a PowerShell .ps1 file to return and format the functions it's declaring (via AST)
		#>
		param(
			[ValidateScript({
					Test-Path $_ -PathType Leaf
				})]
			$Path,
			$ScriptBlock,
			$Padding,
			$PathToItem
		)

		$AST = if ($Path) {
			if ((Get-Item $Path).Extension -notin '.ps1', '.psm1') {
				return $null
			}
			[System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)

		}
		elseif ($ScriptBlock) {
			[System.Management.Automation.Language.Parser]::ParseInput($Block, [ref]$null, [ref]$null)
		}
		$Declared = $AST.FindAll({
				param ($node)
				$node.GetType().Name -eq 'FunctionDefinitionAst'
			}, $true)
		# return $Declared
		ForEach ($Declaration in $Declared) {

			$Start, $End = $Declaration.Extent.StartLineNumber, $Declaration.Extent.EndLineNumber
			$Name = $Declaration.Name

			& ([ScriptBlock]::Create($Declaration.Extent.Text))
			# Imports the function to use Get-Help to find if it has a


			$Formatted = "$Padding- Function [``$Name``]($PathToItem#L$Start-L$End)"

			if (Get-Command $Name -ErrorAction Ignore -and ($Synopsis = (Get-Help $Name  -ErrorAction Ignore).Synopsis)) {
				$Formatted += ": $($Synopsis -replace "`n", ", ")"
			}
			Write-Output $Formatted
		}
	}

	$BaseDepth = Get-Depth $Path
	# How many slashes (or backslashes) the base directory contains
	# This will be used to determine the needed indentation

	$BasePath = (Get-Item $Path).FullName

	function Invoke-TreeRender ($Path) {
		<#
		.SYNOPSIS
		Formats each file in given directory, sub-function used to support recursion
		#>
		Get-ChildItem $Path -Force:$Force | ForEach-Object {
			$Padding = (" " * $Indentation) * ((Get-Depth $PSItem) - $BaseDepth - 1)
			$Name = $_.Name
			if (Test-Path $_ -PathType Container) { $Name = $SEP + $Name + $SEP }
			if (!$NoHyperlinks -and $RepoBase) {
				$PathToItem = "$($_.FullName -Replace [Regex]::Escape($BasePath), '')"

				$PathToItem = $PathToItem -replace "\\", "" -replace "//", ""
				$PathToItem = [IO.Path]::Join($RepoBase, $PathToItem)

				$Name = "$BulletChar [$($Name.Replace("\","\\"))]($PathToItem)"
			}
			if ($_.Extension -eq '.ps1' -and ($Synopsis = (Get-Help -Name $_ -ErrorAction Ignore).Synopsis)) {
				# Both assigns
				if ($Name -ne $_.Name) {
					$Name += ": $Synopsis"
				}
			}
			Write-Output "$Padding$Name"
			if (Test-Path $_ -PathType Container) {
				if (Get-ChildItem $_ -Force:$Force) {
					Invoke-TreeRender $_
				}
			}
			elseif (Test-Path $_ -PathType Leaf) {
				$Parameters = @{
					Path       = $_
					Padding    = $Padding + (" " * $Indentation)
					PathToItem = $PathToItem
				}
				Get-ScriptDeclarations @Parameters
			}
		}
	}

	Invoke-TreeRender $Path

}