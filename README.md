# Features
- User Regular Expression to add highlight (see `:help highlight`) of the text.
- Persistent across different sessions because everything is stored as Json files.
- Assign any highlight group to the text you want to highlight 
- Use automatically created highlight groups that give a good contrast.
- Assign highlights to different buffers based on their `filetypes` (see `:help filetype`)

# Commands
## HiReg
The first command will be `HiReg` that allows to highlight regexes.

    HiReg <regex> [highlight_group] [file_types]

1. `<regex>` is **required** define the text that should be highlighted. **The regex is Vim-based.**
    - It should be written without any spaces. If spaces are necessary you can use `\s` to define a single space, it is part of standard vim regex syntax (see `:help regexp`).
2. `highlight_group` is **optional** and allows to  provided a name of the highlight group you want to use for highlighting of the text. 
    - If it is not present, a new highlight group will be created (or reused if it wasn't created before) out of a set of default colors (see `:help gui-colors`). The colors are organized in a way to provided the highest contrast when they are added as `guifg` and `guibg` randomly.
    > [!NOTE]
    > Because the colors are basic it shouldn't matter if `termguicolors` is enabled or not
3. `[file_types]` is **optional** and allows to set which `filetype` of a buffer can the highlight be applied to
    - If present, several `filetypes` can be separated by a comma *without* any spaces (i.e. `lua,js,c`
        - A special value as `""` (two double quotes) can be used to define a buffer with *no filetype* set (i.e. `lua,"",c`)
    - if not present, the highlight is applied to all the buffers

- Highlights are unique based on the regular expression provided (might be changed in the future with support cwd based highlights)
- Each regex will be pre-pended with `\v` making it a `very magic` regular expression (see `:help \v`). So writing something like `test` will be stored as `\vtest`. *In future it can be changed.*

## HiRegListRegs
In order to see the list of all the created highlights you can use `HiRegListRegs` command.

    HiRegListRegs [regex]

1. `[regex]` is **optional** and allows to find the highlight based on its regex 
    - if not present, all the stored highlights will be shown
    ![HiRegListRegs Example](./data/HiRegListRegs-Example.mp4) 

<video src="./data/HiRegListRegs-Example.mp4" controls></video>
