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
    if highlight_group_name then
        assert(type(highlight_group_name) == "string", "highlight_group_name should be of a type 'string'")
        hi_reg.highlight_group = highlight_group_name
    else
        hi_reg.highlight_group = M.create_random_hi_group()
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
        utils.clear_hi_reg_from_buffers(hi_reg, hi_regs)

        local answer = vim.fn.input({
            prompt = string.format(
                "Do you want to override the highlight?%s"
                .. "%s%s"
                .. "[yes\\no] > ",
                utils.get_line_separator(),
                -- the inspect adds a forward slash to a forward slash
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

    M.set_hi_reg(hi_reg)

    utils.print_wihout_hit_enter(
        string.format("HiReg Created: regex:[%s], highlight_group:[%s], filetypes:%s",
            hi_reg.regex, hi_reg.highlight_group, vim.inspect(hi_reg.filetypes)))
end

-- TODO asign the color that was not used
-- TODO check if the color exists
--- @return string - created highlight group name
M.create_random_hi_group = function()
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

    -- if the hi_group is not stored, store it
    local highlight_groups = utils.get_json_decoded_data(Opts.highlight_groups)
    if not highlight_groups[highlight_group.name] then
        highlight_groups[highlight_group.name] = highlight_group
        utils.write_data(Opts.highlight_groups, highlight_groups)
    end

    return highlight_group.name
end

--- @param hi_reg HiReg
M.set_hi_reg = function(hi_reg)
    assert(hi_reg)

    local command = utils.get_command(hi_reg)
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

        if opts.range == 2 then
            if opts.line1 ~= opts.line2 then
                vim.notify("A multiline for the Regular Expression is not available. Select within a single line")
                return
            end

            local start_row_start_col = vim.api.nvim_buf_get_mark(0, "<")
            local end_row_end_col = vim.api.nvim_buf_get_mark(0, ">")

            regex = vim.api.nvim_buf_get_text(0,
                start_row_start_col[1] - 1, -- weird zero based indexing
                start_row_start_col[2],
                end_row_end_col[1] - 1,
                end_row_end_col[2] + 1,
                {})[1]

            -- literal match with the escape of very no-magic patterns
            regex = '\\V' .. vim.fn.escape(regex, '\\')
            regex = regex:gsub('%s', '\\s')
        else
            -- TODO: FEAT: based on the configuration options decide the ~magic level~
            regex = '\\v' .. regex
        end

        if not regex then
            vim.notify("Usage: HighlightRegex <regex> [color] [filetype]", vim.log.levels.ERROR)
            return
        end

        highlight_text(regex, color, filetype)
    end,
    {
        nargs = "*",
        range = true,
        desc = "Highlight text in a specified filetype buffer"
    }
)
vim.api.nvim_create_user_command(
    "HiRegSetReg",
    function(opts)
        local regex = opts.fargs[1]
        local param = opts.fargs[2]
        local value = opts.fargs[3]

        --- allow empty value for filetypes
        --- distinct between all filetypes and empty ""
        -- assert(regex and param and value, "1:regex, 2:param and 3:value arguments should be present")

        local hi_regs = utils.get_json_decoded_data(Opts.hi_regs)

        assert(regex, "1:regex argument should be present")
        assert(hi_regs[regex], string.format("couldn't find the Highlight Regex using 1:regex: '%s'", regex))

        assert(param, "2:param argument should be present")
        assert(param == 'regex'
            or param == 'highlight_group'
            or param == 'filetypes',
            "2:param doesn't match 'regex', 'highlight_group' or 'filetypes'")

        if param == 'regex' and value == nil then
            assert(value, "3:value argument should be present for param:" .. param)
        end


        --- @type HiReg
        local hi_reg_old = {
            regex = regex,
            highlight_group = hi_regs[regex].highlight_group,
            filetypes = hi_regs[regex].filetypes,
            exclude_filetypes = {}
        }

        if param == 'filetypes' then
            local filetypes = {}
            if value == nil then
                value = "" -- any filetype
            end

            local s = 1
            for e = 1, #value do
                if value:sub(e, e) == ',' then
                    local filetype = value:sub(s, e - 1)
                    -- allow to specify empty filetypes using double quotes
                    if filetype == '""' then
                        filetype = ''
                    end
                    table.insert(filetypes, filetype)
                    s = e + 1
                end
            end

            if s <= #value then
                table.insert(filetypes, value:sub(s, #value))
            end

            --- TODO remove duplicates
            hi_regs[regex].filetypes = filetypes
        elseif param == 'regex' then
            -- TODO ask if overwrite is allowed
            hi_regs[regex].regex = value
            hi_regs[value] = hi_regs[regex]
            hi_regs[regex] = nil
            -- keeping the regex as the pointer to the updated hi_reg
            regex = value
        elseif param == 'highlight_group' then
            hi_regs[regex].highlight_group = value and value or M.create_random_hi_group()
        end

        utils.write_data(Opts.hi_regs, hi_regs)
        utils.clear_hi_reg_from_buffers(hi_reg_old, hi_regs)
        M.set_hi_reg(hi_regs[regex])
    end,
    {
        nargs = "+",
        complete = function(arg_lead, cmd_line, cursor_pos)
            local arg_indexes = utils.get_arg_indexes(cmd_line, cursor_pos)
            if arg_indexes.index == 1 then
                --- @type HiReg
                local hi_regs = utils.get_json_decoded_data(Opts.hi_regs)
                local completion = {}

                local i = 1
                for _, value in pairs(hi_regs) do
                    completion[i] = value.regex
                    i = i + 1
                end
                return completion
            elseif arg_indexes.index == 2 then
                return {
                    "regex",
                    "highlight_group",
                    "filetypes"
                }
            elseif arg_indexes.index == 3 then
                --- @type [HiReg]
                local hi_regs = utils.get_json_decoded_data(Opts.hi_regs)

                local regex = arg_indexes.args[1].content
                local property = arg_indexes.args[2].content

                if not hi_regs[regex] or not hi_regs[regex][property] then
                    return {}
                end

                -- TODO make empty filetype "" be selected
                if property == 'filetypes' then
                    return { table.concat(hi_regs[regex].filetypes, ',') }
                end

                return { hi_regs[regex][property] }
            end
        end,
        desc = "Set Property of The Regular Expression"
    }
)

vim.api.nvim_create_user_command(
    "HiRegListRegs",
    function(opts)
        local fargs = opts.fargs
        if #fargs == 0 then
            utils.print(utils.get_json_decoded_data(Opts.hi_regs))
        elseif #fargs == 1 then
            local regex = fargs[1]
            local hi_regs = utils.get_json_decoded_data(Opts.hi_regs)
            if hi_regs[regex] then
                utils.print({ hi_regs[regex] })
            else
                print(string.format("HiRegListRegs: Couldn't find a HiReg using the regex:[%s]", regex))
            end
        else
            print("HiRegListRegs: Number of arguments can be only 0 or 1")
        end
    end,
    {
        nargs = "*",
        complete = function()
            --- @type HiReg
            local hi_regs = utils.get_json_decoded_data(Opts.hi_regs)
            local completion = {}

            local i = 1
            for _, value in pairs(hi_regs) do
                completion[i] = value.regex
                i = i + 1
            end
            return completion
        end,
        desc =
            "No Args: List All HiRegs\n"
            .. "1 Arg: List A HiReg Matching the Regular Expression"
    }
)
vim.api.nvim_create_user_command(
    "HiRegListHighlights",
    function(opts)
        P(utils.get_json_decoded_data(Opts.highlight_groups))
    end,
    { desc = "List All Highlights" }
)


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

        utils.clear_hi_reg_from_buffers(hi_reg, hi_regs)
    end,
    {
        nargs = 1,
        complete = function()
            --- @type HiReg
            local hi_regs = utils.get_json_decoded_data(Opts.hi_regs)
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


vim.api.nvim_create_autocmd({ "BufNew", "VimEnter" }, {
    nested = true,
    callback = function(args)
        if args.event == "VimEnter" then
            M.load_hi_regx_for_filetype(vim.bo[args.buf].filetype)
            return
        end

        -- Uses nested autocmd because `vim.api.nvim_buf_line_count(args.buf)` would return zero
        vim.api.nvim_create_autocmd({ "BufEnter" }, {
            once = true,
            -- Too many data files were opened on a big project that lead to major issues because
            -- his event called not once but multiple times despite "once" property,
            -- maybe a concurrency issue.
            -- Linking this event to the buffer that created fixes it.
            buffer = args.buf,

            callback = function(args)
                M.load_hi_regx_for_filetype(vim.bo[args.buf].filetype)
            end
        })
    end
})


M.load_hi_regx_for_filetype = function(filetype)
    --- @type {[string]: HiReg}
    local hi_regs = utils.get_json_decoded_data(Opts.hi_regs)
    local highlight_groups = utils.get_json_decoded_data(Opts.highlight_groups)

    for _, hi_reg in pairs(hi_regs) do
        if #hi_reg.filetypes == 0 then
            if highlight_groups[hi_reg.highlight_group] then
                vim.cmd(string.format("highlight %s guifg='%s' guibg='%s'",
                    hi_reg.highlight_group,
                    highlight_groups[hi_reg.highlight_group].guifg,
                    highlight_groups[hi_reg.highlight_group].guibg
                ))
            end

            vim.cmd(utils.get_command(hi_reg))
        end

        for _, hi_reg_filetype in pairs(hi_reg.filetypes) do
            if hi_reg_filetype == filetype then
                -- TODO check if hi is not present in data base, don't add
                if highlight_groups[hi_reg.highlight_group] then
                    vim.cmd(string.format("highlight %s guifg='%s' guibg='%s'",
                        hi_reg.highlight_group,
                        highlight_groups[hi_reg.highlight_group].guifg,
                        highlight_groups[hi_reg.highlight_group].guibg
                    ))
                end

                vim.cmd(utils.get_command(hi_reg))
            end
        end
    end
end
return M
