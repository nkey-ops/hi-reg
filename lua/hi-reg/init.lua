-- TODO Load all hi_groups or only each when needed?
--
-- invariants:
-- a list of hi_regs   present in the db MUST contain ALL ones in the current session :syntax
-- a list of hi_groups present in the db MUST contain ALL ones in the current session :higlight
--

local utils = require("hi-reg.utils")
local M = {}
local L = {}

--- @class HiRegOpts configurations for the hi-reg
--- @field data_dir string?  default:"~/.cache/nvim/" | directory where "hi-reg" directory
---                          will be created and store all the data
local Opts = {
    data_dir = vim.fn.glob("~/.cache/nvim/"), -- the path to data files
    hi_regs = nil,
    highlight_groups = nil,
}

local is_setup = false

--- @param opts HiRegOpts?;
M.setup = function(opts)
    if not opts then
        opts = Opts
    else
        assert(type(opts) == 'table', "opts should be of a type table")
        opts = vim.tbl_extend("force", Opts, opts)
    end

    opts.data_dir = utils.handle_data_dir(opts.data_dir)
    Opts = opts

    Opts.hi_regs = Opts.data_dir .. '/hi-reg.json'
    assert(io.open(Opts.hi_regs, 'a+')):close()

    Opts.highlight_groups = Opts.data_dir .. '/highlight_groups.json'
    assert(io.open(Opts.highlight_groups, 'a+')):close()

    is_setup = true
end

local colors = {
    black_contrast = {
        "Cyan",
        "LightBlue",
        "LightCyan",
        "LightGray",
        "LightGreen",
        "LightMagenta",
        "LightRed",
        "LightYellow",
        "Magenta",
        "Orange",
        "Purple",
        "Red",
        "White",
        "Yellow",
        "DarkYellow",
    },
    white_contrast = {
        "Black",
        "DarkBlue",
        "Blue",
        "Brown",
        "DarkCyan",
        "DarkGray",
        "DarkGreen",
        "DarkMagenta",
        "DarkRed",
        "Gray",
        "SeaGreen",
        "SlateBlue",
        "Violet",
        "Green",
    }
}


--- @class HiReg
--- @field regex string
--- @field highlight_group string
--- @field filetypes [string]
--- @field exclude_filetypes [string]
---

--- @class Highlight_Group
--- @field name string
--- @field guifg string?
--- @field guibg string?

--- @param hi_reg HiReg
--- @return string
local function get_command(hi_reg)
    assert(hi_reg)

    -- Define the command to apply the highlight to the specified filetype
    -- if &filetype == "%s"
    -- endif
    local command = string.format(
        [[
        silent! syntax match %s "\v%s"
         ]],
        hi_reg.highlight_group, -- Highlight Group Name
        hi_reg.regex            -- Escape slashes in regex
    )

    return command
end

--- @param regex string regular expression to createa a highlight for
--- @param highlight_group_name? string default:random color | optional color for highlight
--- @param filetype? string default:current filetype | optional filetype to apply the highlight to
local function highlight_text(regex, highlight_group_name, filetype)
    assert(is_setup, "The setup() wasn't called")

    -- Check if the color exists and is a string
    if type(regex) ~= "string" then
        vim.notify("Regex must be a non-empty string", vim.log.levels.ERROR)
        return
    end

    --- @type HiReg
    local hi_reg = {
        regex = regex,
        filetypes = {}
    }
    -- Check if the color exists and is a string
    -- TODO asign the color that was not used
    -- TODO check if the color exists
    if highlight_group_name then
        assert(type(highlight_group_name) == "string", "highlight_group_name should be of a type 'string'")
        hi_reg.highlight_group = highlight_group_name
    else
        local is_black_contrast = math.random() >= 0.5
        local is_fg_main = math.random() >= 0.5
        local guifg, guibg

        if is_black_contrast then
            local random_color = colors.black_contrast[math.random(#colors.black_contrast)]
            guifg = is_fg_main and "Black" or random_color
            guibg = not is_fg_main and "Black" or random_color
        else
            local random_color = colors.white_contrast[math.random(#colors.white_contrast)]
            guifg = is_fg_main and "White" or random_color
            guibg = not is_fg_main and "White" or random_color
        end

        -- TODO escape color
        -- Create highlight group if it doesn't exist
        -- TODO deal with conflicts when gsub will
        -- replace from different pattersn characters and turn them into the same group
        -- local highlight_group = color
        --- @type Highlight_Group
        local highlight_group = {
            name = "HiReg_" .. guifg .. "__" .. guibg,
            guifg = guifg,
            guibg = guibg
        }

        vim.cmd(string.format("highlight %s guifg='%s' guibg='%s'",
            highlight_group.name,
            highlight_group.guifg,
            highlight_group.guibg
        ))

        hi_reg.highlight_group = highlight_group.name

        -- if the hi_group is not stored, store it
        local highlight_groups = utils.get_json_decoded_data(Opts.highlight_groups)
        if not highlight_groups[highlight_group.name] then
            highlight_groups[highlight_group.name] = highlight_group
            utils.write_data(Opts.highlight_groups, highlight_groups)
        end
    end

    -- Check if the filetype exists and is a string
    -- TODO apply to any filetype
    if filetype then
        assert(type(filetype) == "string", "filetype should be of a type 'string'")
    else
        filetype = vim.bo.filetype
    end
    table.insert(hi_reg.filetypes, filetype)

    local hi_regs = utils.get_json_decoded_data(Opts.hi_regs)

    -- If hi_reg already exists
    --      ask if we want to overwrite it
    if (hi_regs[hi_reg.regex]) then
        L.clear_hi_reg_from_buffers(hi_reg)

        local answer = vim.fn.input({
            prompt = string.format(
                "Do you want to override the highlight?%s"
                .. "%s%s"
                .. "[yes\\no] > ",
                utils.get_line_separator(),
                vim.inspect(hi_regs[hi_reg.regex]),
                utils.get_line_separator()
            )
        }):lower()

        --- @type boolean
        local isYes = answer:match("^y$") or answer:match("^ye$") or answer:match("^yes$")

        if not isYes then
            return
        end
        print(utils.get_line_separator())
    end

    hi_regs[hi_reg.regex] = hi_reg
    utils.write_data(Opts.hi_regs, hi_regs)

    local command = get_command(hi_reg)
    -- execute the command inside each buffer
    for _, buf in pairs(vim.api.nvim_list_bufs()) do
        if #hi_reg.filetypes == 0 then
            vim.api.nvim_buf_call(buf, function()
                vim.cmd(command)
            end)
        end

        for _, filetype in pairs(hi_reg.filetypes) do
            if filetype == vim.bo[buf].filetype then
                vim.api.nvim_buf_call(buf, function()
                    vim.cmd(command)
                end)
            end
        end
    end

    utils.print_wihout_hit_enter(
        string.format("Highlight Created: [s] %s [buffers]",
            hi_reg.regex, hi_reg.highlight_group, hi_reg.filetypes))
end




-- highlight for any file type
-- hightlight for a specific file type
-- highlight for a current buffer
--
-- random color
--
-- when custom highlight updates, save it
-- support quotes for regex and colors
--
-- Define the command
vim.api.nvim_create_user_command(
    "HiReg",
    function(opts)
        local args = opts.fargs
        local regex = args[1]
        local color = args[2]
        local filetype = args[3]
        if not regex then
            vim.notify("Usage: HighlightRegex <regex> [color] [filetype]", vim.log.levels.ERROR)
            return
        end

        highlight_text(regex, color, filetype)
    end,
    { nargs = "+", desc = "Highlight text in a specified filetype buffer" }
)

vim.api.nvim_create_user_command(
    "HiRegListRegs",
    function(opts)
        P(utils.get_json_decoded_data(Opts.hi_regs))
    end,
    { desc = "List All Regular Exprestions" }
)
vim.api.nvim_create_user_command(
    "HiRegListHighlights",
    function(opts)
        P(utils.get_json_decoded_data(Opts.highlight_groups))
    end,
    { desc = "List All Highlights" }
)

--- @param hi_reg HiReg
L.clear_hi_reg_from_buffers = function(hi_reg)
    assert(type(hi_reg) == 'table', "hi_reg should be non nil and of the type 'table'")

    local hi_regs = utils.get_json_decoded_data(Opts.hi_regs)

    --
    -- 1.* run through each open buffer
    -- 2. check whether the buffer's filetype matches any
    --    hi_reg's filetyps / if matches
    -- 3.* run ':syntax clear "highlight_group"' within the buffer
    -- 4. go through each hi_reg_saved
    -- 5. check whether hi_reg_saved.highlight_group
    --    matches hi_reg.highlight_group / if matches
    -- 6. check if the hi_reg_saved has any filetypes matching
    --    the buffer's filetype of the current iteration / if matches
    -- 7. add the removed :syntax match for the hi_reg_saved
    --
    --
    -- 1.* 'syntax clear' only applies to the current buffer and
    --      needs to be executed within that buffer
    -- 3.* ':syntax clear' will remove all matchings regexes for the "highligh_group"
    --      so we need to restore all others removed with the same regex and buffer
    for _, buf in pairs(vim.api.nvim_list_bufs()) do
        if #hi_reg.filetypes == 0 then
            vim.api.nvim_buf_call(buf, function()
                vim.cmd("syntax clear " .. hi_reg.highlight_group)

                for _, hi_reg_saved in pairs(hi_regs) do
                    if hi_reg.highlight_group == hi_reg_saved.highlight_group then
                        vim.cmd(get_command(hi_reg_saved))
                    end
                end
            end)
        end

        for _, hi_reg_filetype in pairs(hi_reg.filetypes) do
            if hi_reg_filetype == vim.bo[buf].filetype then
                vim.api.nvim_buf_call(buf, function()
                    vim.cmd("syntax clear " .. hi_reg.highlight_group)

                    for _, hi_reg_saved in pairs(hi_regs) do
                        if hi_reg.highlight_group == hi_reg_saved.highlight_group then
                            for _, hi_reg_saved_filetype in pairs(hi_reg_saved.filetypes) do
                                if hi_reg_saved_filetype == vim.bo[buf].filetype then
                                    vim.cmd(get_command(hi_reg_saved))
                                end
                            end
                        end
                    end
                end)
            end
        end
    end
end

vim.api.nvim_create_user_command(
    "HiRegDeleteReg",
    function(opts)
        local regex = opts.fargs[1]
        assert(regex, "Regular Expression is not present")

        --- @type HiReg
        local hi_regs = utils.get_json_decoded_data(Opts.hi_regs)
        local hi_reg = hi_regs[regex]
        assert(hi_reg, "Highlighted Regular Expression doesn't exist")

        hi_regs[regex] = nil
        utils.write_data(Opts.hi_regs, hi_regs)

        L.clear_hi_reg_from_buffers(hi_reg)
    end,
    {
        nargs = 1,
        complete = function()
            --- @type HiReg
            local hi_regs = utils.get_json_decoded_data(Opts.hi_regs)
            table.sort(hi_regs)
            local completion = {}

            local i = 1
            for _, value in pairs(hi_regs) do
                completion[i] = value.regex
                i = i + 1
            end
            return completion
        end,
        desc = "Delete Highligted Regular Expression"
    }

)


vim.api.nvim_create_autocmd({ "BufNew" }, {
    nested = true,
    callback = function(args)
        -- Uses nested autocmd because `vim.api.nvim_buf_line_count(args.buf)` would return zero
        vim.api.nvim_create_autocmd({ "BufEnter" }, {
            once = true,
            -- Too many data files were opened on a big project that lead to major issues because
            -- his event called not once but multiple times despite "once" property,
            -- maybe a concurrency issue.
            -- Linking this event to the buffer that created fixes it.
            buffer = args.buf,

            callback = function(args)
                --- @type {[string]: HiReg}
                local hi_regs = utils.get_json_decoded_data(Opts.hi_regs)
                local highlight_groups = utils.get_json_decoded_data(Opts.highlight_groups)

                for _, hi_reg in pairs(hi_regs) do
                    for _, filetype in pairs(hi_reg.filetypes) do
                        if filetype == vim.bo[args.buf].filetype then
                            -- TODO check if hi is not present in data base, don't add
                            vim.cmd(string.format("highlight %s guifg='%s' guibg='%s'",
                                hi_reg.highlight_group,
                                highlight_groups[hi_reg.highlight_group].guifg,
                                highlight_groups[hi_reg.highlight_group].guibg
                            ))

                            vim.cmd(get_command(hi_reg))
                        end
                    end
                end
            end
        })
    end
})

return M
