> **Warning**
>
> This was a concept I lost interest in,
> Consider this abandonned, feel free to PR/fork

# Show-ModuleTree 🌳

1. Add the to following lines in your `.MD` (e.g README) file where you want your module tree to grow at:

```markdown
<!---START FOO--->
<!---END FOO--->
```
> **Note**
>
> Replace foo by the name of the `ReplaceBlock` you wish to give it, it will then be parsed by Show-ModuleTree to replace that part of your markdown file

2. Copy `show-moduletree.yaml` to your repo's `/.github/workflows/` and expect a rich tree displaying all of your hard work!

3. Profit (growth)! Here's how mine grew into:

* [/src/](https://github.com/couleur-tweak-tips/Show-ModuleTree/tree/master/src)
  * [/Public/](https://github.com/couleur-tweak-tips/Show-ModuleTree/tree/master/src/Public)
    * [Test.ps1](https://github.com/couleur-tweak-tips/Show-ModuleTree/tree/master/src/Public/Test.ps1)
      * Function ``Invoke-Foo`` - Generates a display of the Baz
      * Filter ``Select-Bar``
    * [/NestedPublicFolder/](https://github.com/couleur-tweak-tips/Show-ModuleTree/tree/master/src/Public/NestedPublicFolder)
      * [NestedPublicFile.ps1]()
         * Function ``Booz`` - Does Bawz
   * [/Private/](https://github.com/couleur-tweak-tips/Show-ModuleTree/tree/master/src/Private)
     * PrivateFile.ps1
       * function ``Show-PrivateFunction`` - I think I got to the point..

> Mind the hyperlinks, the descriptions are parsed from `.SYNOPSIS` when existant

## Customization

* Add `-Spoiler` to hide it **behind a spoiler**. Then you can add it at the **top of your readme**
for everyone to have a glance at a **high-level overview** of your code's structure
* Change everything about the directories, add a description, override the display name and hyperlink (e.g link to the nested README.MD)
