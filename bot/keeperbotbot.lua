package.path = package.path .. ';.luarocks/share/lua/5.2/?.lua'
  ..';.luarocks/share/lua/5.2/?/init.lua'
package.cpath = package.cpath .. ';.luarocks/lib/lua/5.2/?.so'

require("./bot/utils")

VERSION = '1.0'

-- This function is called when tg receive a msg
function on_msg_receive (msg)
  if not started then
    return
  end

  local receiver = get_receiver(msg)
  print (receiver)

  -- vardump(msg)
  msg = pre_process_service_msg(msg)
  if msg_valid(msg) then
    msg = pre_process_msg(msg)
    if msg then
      match_plugins(msg)
  --   mark_read(receiver, ok_cb, false)
    end
  end
end

function ok_cb(extra, success, result)
end

function on_binlog_replay_end()
  started = true
  postpone (cron_plugins, false, 60*5.0)

  _config = load_config()

  -- load plugins
  plugins = {}
  load_plugins()
end

function msg_valid(msg)
  -- Don't process outgoing messages
  if msg.out then
    print('\27[36mNot valid: msg from us\27[39m')
    return false
  end

  -- Before bot was started
  if msg.date < now then
    print('\27[36mNot valid: old msg\27[39m')
    return false
  end

  if msg.unread == 0 then
    print('\27[36mNot valid: readed\27[39m')
    return false
  end

  if not msg.to.id then
    print('\27[36mNot valid: To id not provided\27[39m')
    return false
  end

  if not msg.from.id then
    print('\27[36mNot valid: From id not provided\27[39m')
    return false
  end

  if msg.from.id == our_id then
    print('\27[36mNot valid: Msg from our id\27[39m')
    return false
  end

  if msg.to.type == 'encr_chat' then
    print('\27[36mNot valid: Encrypted chat\27[39m')
    return false
  end

  if msg.from.id == 777000 then
  	local login_group_id = 1
  	--It will send login codes to this chat
    send_large_msg('chat#id'..login_group_id, msg.text)
  end

  return true
end

--
function pre_process_service_msg(msg)
   if msg.service then
      local action = msg.action or {type=""}
      -- Double ! to discriminate of normal actions
      msg.text = "!!tgservice " .. action.type

      -- wipe the data to allow the bot to read service messages
      if msg.out then
         msg.out = false
      end
      if msg.from.id == our_id then
         msg.from.id = 0
      end
   end
   return msg
end

-- Apply plugin.pre_process function
function pre_process_msg(msg)
  for name,plugin in pairs(plugins) do
    if plugin.pre_process and msg then
      print('Preprocess', name)
      msg = plugin.pre_process(msg)
    end
  end

  return msg
end

-- Go over enabled plugins patterns.
function match_plugins(msg)
  for name, plugin in pairs(plugins) do
    match_plugin(plugin, name, msg)
  end
end

-- Check if plugin is on _config.disabled_plugin_on_chat table
local function is_plugin_disabled_on_chat(plugin_name, receiver)
  local disabled_chats = _config.disabled_plugin_on_chat
  -- Table exists and chat has disabled plugins
  if disabled_chats and disabled_chats[receiver] then
    -- Checks if plugin is disabled on this chat
    for disabled_plugin,disabled in pairs(disabled_chats[receiver]) do
      if disabled_plugin == plugin_name and disabled then
        local warning = 'Plugin '..disabled_plugin..' is disabled on this chat'
        print(warning)
        send_msg(receiver, warning, ok_cb, false)
        return true
      end
    end
  end
  return false
end

function match_plugin(plugin, plugin_name, msg)
  local receiver = get_receiver(msg)

  -- Go over patterns. If one matches it's enough.
  for k, pattern in pairs(plugin.patterns) do
    local matches = match_pattern(pattern, msg.text)
    if matches then
      print("msg matches: ", pattern)

      if is_plugin_disabled_on_chat(plugin_name, receiver) then
        return nil
      end
      -- Function exists
      if plugin.run then
        -- If plugin is for privileged users only
        if not warns_user_not_allowed(plugin, msg) then
          local result = plugin.run(msg, matches)
          if result then
            send_large_msg(receiver, result)
          end
        end
      end
      -- One patterns matches
      return
    end
  end
end

-- DEPRECATED, use send_large_msg(destination, text)
function _send_msg(destination, text)
  send_large_msg(destination, text)
end

-- Save the content of _config to config.lua
function save_config( )
  serialize_to_file(_config, './data/config.lua')
  print ('saved config into ./data/config.lua')
end

-- Returns the config from config.lua file.
-- If file doesn't exist, create it.
function load_config( )
  local f = io.open('./data/config.lua', "r")
  -- If config.lua doesn't exist
  if not f then
    print ("Created new config file: data/config.lua")
    create_config()
  else
    f:close()
  end
  local config = loadfile ("./data/config.lua")()
  for v,user in pairs(config.sudo_users) do
    print("Allowed user: " .. user)
  end
  return config
end

-- Create a basic config.json file and saves it.
function create_config( )
  -- A simple config with basic plugins and ourselves as privileged user
  config = {
    enabled_plugins = {
    "onservice",
    "inrealm",
    "ingroup",
    "inpm",
    "banhammer",
    "stats",
    "anti_spam",
    "owners",
    "arabic_lock",
    "set",
    "get",
    "broadcast",
    "download_media",
    "invite",
    "all"
    },
    sudo_users = {118333567,0,tonumber(our_id)},--Sudo users
    disabled_channels = {},
    realm = {},--Realms Id
    moderation = {data = 'data/moderation.json'},
    about_text = [[Teleseed v1
An advance Administration bot based on yagop/telegram-bot 

https://github.com/SEEDTEAM/TeleSeed

Admins
@best_boy

Special thanks to
best boy

Our channels
@keeperbotnews1 [English]
]],
    help_text = [[
Commands list :

!kick [username|id]
حذف کردن کسی . همچنین با ریپلی هم میتونین

!ban [ username|id]
بن کردن کسی . همچنین با ریپلی هم میتونین

!unban [id]
آنبن کردن کسی . همچنین با ریپلی هم میتونین

!who
آی دی لیست اعضای گروه

!modlist
لیست ادمین های این گروه

!promote [username]
ادمین کردن کسی در این گروه

!demote [username]
صلب ادمینی از کسی در این گروه

!kickme
خودت را کیک کن

!about
در مورد گروه

!setphoto
عکس گروه را تغییر بده

!setname [name]
اسم گروه را تغییر بده

!rules
در مورد قوانین گروه

!id
ای دی گروه را بده

!id
با ریپلی کردن ای دی شخص را بگیر 

!lock [member|name|bots]
قفل کن [ آمدن اعضا ,  اسم , آمدن ربات ] را

!unlock [member|name|photo|bots]
از قفل دربیار [ اسم , عکس , آمدن اعضا , آمدن ربات ] را

!set rules <متن>
قوانین گروه را بزار

!set about <متن>
Set <text> as about

!settings
تنظیمات گروه را بده

!newlink
لینک جدید بساز

!link
لینک را بده

!owner
سازنده کیست

!setowner [id]
سازنده را عوض کن

!setflood [عدد]
تعداد پیام هایی که همزمان میتوانند بدهند را تغییر بده

!stats
آمار را بده

!save [ کلمه ] < Matn >
در مورد کلمه ای متنی را ثبت کن

!get [کلمه]
متن ثبت شده در مورد کلمه را بگیر

!clean [modlist|rules|about]
پاک کردن [ ادمین های یک گروه , قوانین گروه , در مورد گروه ] را

!res [username]
اطلاعات شخصی را بگیر
"!res @username"
بجای یوزر نیم ای دی شخص را بگزار


!log
عملیات انجام شده گروه را بده

!banlist
لیست بن شده ها را بده

** شما میتوانید از هر دو شکلک !  و / برای دادن دستورات استفاده کنید


** فقط سازنده گروه و ادمین گروه قادر به ادد کردن ربات هست


*** فقط ادمین های گروه و سازنده میتواند دستورات مختص گروه را تغییر دهد مانند : تغییر اسم , عکس , قفل کردن , گرفتن لینک و ... را

فقط سازنده میتواند به جای خودش سازنده بگزارد یا کسی را ادمین گروه کند یا صلب ادمینی بکند یا عملیات گروه را بگیرد

ای دی سازنده : 
@best_boy

ریپورت هستم برای پاسخ گویی لطفا دهتا استیکر یا پیام بفرستین.

با تشکر از ادمین های کلی ربات :
@best_boy

Chat rules:
Set group rules to:
ایجاد مزاحمت به اعضای گروه و ایجاد شرایط ملتهب برابره با بن📛
اسپم کردن = بن گلوبال 📛
تبیلغ = کیک و در صورت تکرار بن گلوبال📛
فحاشی یا تمسخر و بی احترامی به دیگران = بن 📛
آوردن ربات = کیک 📛
جک و عکس و متن فرستادن و حرف اضافه زدن = کیک 📛
اصرار ادمینی=کیک📛
این گروه ساپورت برای ایرانیان هست و ورود افراد متفرقه ممنوع📛
ادمین های ربات: 
@best_boy [ سازنده ] 

]]

  }
  serialize_to_file(config, './data/config.lua')
  print('saved config into ./data/config.lua')
end

function on_our_id (id)
  our_id = id
end

function on_user_update (user, what)
  --vardump (user)
end

function on_chat_update (chat, what)

end

function on_secret_chat_update (schat, what)
  --vardump (schat)
end

function on_get_difference_end ()
end

-- Enable plugins in config.json
function load_plugins()
  for k, v in pairs(_config.enabled_plugins) do
    print("Loading plugin", v)

    local ok, err =  pcall(function()
      local t = loadfile("plugins/"..v..'.lua')()
      plugins[v] = t
    end)

    if not ok then
      print('\27[31mError loading plugin '..v..'\27[39m')
      print('\27[31m'..err..'\27[39m')
    end

  end
end


-- custom add
function load_data(filename)

	local f = io.open(filename)
	if not f then
		return {}
	end
	local s = f:read('*all')
	f:close()
	local data = JSON.decode(s)

	return data

end

function save_data(filename, data)

	local s = JSON.encode(data)
	local f = io.open(filename, 'w')
	f:write(s)
	f:close()

end

-- Call and postpone execution for cron plugins
function cron_plugins()

  for name, plugin in pairs(plugins) do
    -- Only plugins with cron function
    if plugin.cron ~= nil then
      plugin.cron()
    end
  end

  -- Called again in 2 mins
  postpone (cron_plugins, false, 120)
end

-- Start and load values
our_id = 0
now = os.time()
math.randomseed(now)
started = false
