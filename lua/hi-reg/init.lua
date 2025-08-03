local utils = require("hi-reg.utils")
local M = {}

--- @class HiRegOpts configurations for the hi-reg
--- @field data_dir string?  default:"~/.cache/nvim/" | directory where "hi-reg" directory
---                          will be created and store all the data
local Opts = {
    data_dir = vim.fn.glob("~/.cache/nvim/"), -- the path to data files
    hiregs = nil,
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

    Opts.hiregs = Opts.data_dir .. '/hi-reg.json'
    assert(io.open(Opts.hiregs, 'a+')):close()

    Opts.highlight_groups = Opts.data_dir .. '/highlight_groups.json'
    assert(io.open(Opts.highlight_groups, 'a+')):close()

    is_setup = true
end

-- Function to highlight text based on regex, color, and filetype
local default_colors = {
    "Red", "LightRed", "DarkRed",
    "Green", "LightGreen", "DarkGreen", "SeaGreen",
    "Blue", "LightBlue", "DarkBlue", "SlateBlue",
    "Cyan", "LightCyan", "DarkCyan",
    "Magenta", "	LightMagenta", "DarkMagenta",
    "Yellow", "LightYellow", "Brown", "DarkYellow",
    "Gray", "LightGray", "DarkGray",
    "Black", "White",
    "Orange", "Purple", "Violet"
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
--- @param color? string default:random color | optional color for highlight
--- @param filetype? string default:current filetype | optional filetype to apply the highlight to
local function highlight_text(regex, color, filetype)
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
    if color then
        assert(type(color) ~= "string", "color should be of a type 'string'")
    else
        color = default_colors[math.random(#default_colors)]
    end

    -- Check if the filetype exists and is a string
    -- TODO apply to any filetype
    if filetype then
        assert(type(filetype) ~= "string", "filetype should be of a type 'string'")
    else
        filetype = vim.bo.filetype
    end

    table.insert(hi_reg.filetypes, filetype)

    -- TODO escape color
    -- Create highlight group if it doesn't exist
    -- TODO deal with conflicts when gsub will
    -- replace from different pattersn characters and turn them into the same group
    -- local highlight_group = color
    --- @type Highlight_Group
    local highlight_group = {
        name = "HiReg_" .. color,
        guifg = color
    }
    hi_reg.highlight_group = highlight_group.name;

    local hiregs = utils.get_json_decoded_data(Opts.hiregs)

    if (hiregs[hi_reg.regex]) then
        local answer = vim.fn.input({
            prompt = string.format(
                "Do you want to override the highlight?%s"
                .. "%s%s"
                .. "[yes\\no] > ",
                utils.get_line_separator(),
                vim.inspect(hiregs[hi_reg.regex]),
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

    hiregs[hi_reg.regex] = hi_reg
    utils.write_data(Opts.hiregs, hiregs)

    local highlight_groups = utils.get_json_decoded_data(Opts.highlight_groups)
    if not highlight_groups[highlight_group.name] then
        highlight_groups[highlight_group.name] = highlight_group
        utils.write_data(Opts.highlight_groups, highlight_groups)
    end

    local command = get_command(hi_reg)
    vim.cmd(string.format("highlight %s guifg='%s'",
        highlight_group.name,
        highlight_group.guifg))

    for _, buf in pairs(vim.api.nvim_list_bufs()) do
        if #hi_reg.filetypes == 0 then
            vim.cmd(command)
        end

        for _, filetype in pairs(hi_reg.filetypes) do
            if filetype == vim.bo[buf].filetype then
                vim.api.nvim_buf_call(buf, function()
                    vim.cmd(command)
                end)
            end
        end
    end

    utils.print_wihout_hit_enter("Highlight applied to " .. filetype .. " buffers", vim.log.levels.INFO)
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
                local hiregs = utils.get_json_decoded_data(Opts.hiregs)
                local highlight_groups = utils.get_json_decoded_data(Opts.highlight_groups)

                for _, hi_reg in pairs(hiregs) do
                    for _, filetype in pairs(hi_reg.filetypes) do
                        if filetype == vim.bo[args.buf].filetype then
                            -- TODO check if hi is not present in data base, don't add
                            vim.cmd(string.format("highlight %s guifg='%s'",
                                hi_reg.highlight_group,
                                highlight_groups[hi_reg.highlight_group].guifg))

                            vim.cmd(get_command(hi_reg))
                        end
                    end
                end
            end
        })
    end
})

return M
