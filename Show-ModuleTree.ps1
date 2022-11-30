function Show-ModuleTree {
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

	if (!$RepoURL -and !$NoHyperlinks){
		if ((Test-Path "$Path\.git") -and (Get-Command git -ErrorAction Ignore)){
			Push-Location $Path
			$RepoURL = (git config remote.origin.url) -replace '^.+?/|\.git$' -replace "/github.com/",""
			Pop-Location
		}
	} elseif($RepoURL){
		if ($RepoURL -like "*://gitlab.com/*"){
			throw "GitLab isn't supported yet, but feel free to PR!"
		}
		$RepoURL = ($RepoURL) -replace '^.+?/|\.git$' -replace "/github.com/",""
	}

	$RepoBase = if ($LinkRaw){
					"https://raw.githubusercontent.com/$RepoURL/$Branch/"
				}else {
					"https://github.com/$RepoURL/blob/$Branch/"
				}
	if ($PathInRepo -ne $SEP){
		$RepoBase += $PathInRepo
	}


	function Get-Depth ($Path){
		$Path = (Get-Item $Path -Force).FullName.TrimEnd($SEP)
		$Count = ($Path.ToCharArray() | Where-Object {$_ -eq $SEP}).Count
		Write-Verbose "$Path has $Count slashes"
		return $Count
	}

	function Get-ScriptDeclarations {
		param(
			[ValidateScript({
				Test-Path $_ -PathType Leaf
			})]
			$Path,
			$ScriptBlock,
			$Padding,
			$PathToItem
		)
		$AST = if ($Path){
			[System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)

		}elseif($ScriptBlock){
			[System.Management.Automation.Language.Parser]::ParseInput($Block, [ref]$null, [ref]$null)
		}
		$Declared = $AST.FindAll({
			param ($node)
			$node.GetType().Name -eq 'FunctionDefinitionAst'
		}, $true)
		# return $Declared
		ForEach($Declaration in $Declared){
			$Start, $End = $Declaration.Extent.StartLineNumber, $Declaration.Extent.EndLineNumber
			Write-Output "$Padding- Function [``$($Declaration.Name)``]($PathToItem#L$Start-L$End)"
		}
	}

	$BaseDepth = Get-Depth $Path
		# How many slashes (or backslashes) the base directory contains
		# This will be used to determine the needed indentation

	$BasePath = (Get-Item $Path).FullName

	function Invoke-TreeRender ($Path){
		Get-ChildItem $Path -Force:$Force | ForEach-Object {
			$Padding = (" " * $Indentation) * ((Get-Depth $PSItem) - $BaseDepth -1)
			$Name = $_.Name
			if (Test-Path $_ -PathType Container){$Name = $SEP + $Name + $SEP}
			if (!$NoHyperlinks -and $RepoBase){
				$PathToItem = "$($_.FullName -Replace [Regex]::Escape($BasePath), '')"

				$PathToItem = $PathToItem -replace "\\", "" -replace "//", ""
				$PathToItem = [IO.Path]::Join($RepoBase, $PathToItem)

				$Name = "$BulletChar [$($Name.Replace("\","\\"))]($PathToItem)"
			}
			Write-Output "$Padding$Name"
			if (Test-Path $_ -PathType Container){
				if (Get-ChildItem $_ -Force:$Force){
					Invoke-TreeRender $_
				}
			}elseif(Test-Path $_ -PathType Leaf){
				$Parameters = @{
					Path = $_
					Padding = $Padding
					PathToItem = $PathToItem
				}
				Get-ScriptDeclarations @Parameters
			}
		}
	}

	Invoke-TreeRender $Path
	
	


}