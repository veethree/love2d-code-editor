lg = love.graphics
fs = love.filesystem


function love.load()
        lex = require("lexer")
        code_editor = require("code_editor")
        ce = code_editor.new(0, 0, lg.getWidth() / 2, lg.getHeight())
        font = lg.newFont("RobotoMono-Medium.ttf", 14)
        ce:set_font(font)
        ce:load("lexer.lua")
end

function love.update(dt)
        ce:update(dt)
end

function love.draw()
        lg.setColor(1, 1, 1, 1)
        ce:draw()
end

function love.keypressed(key)
        if key == "escape" then love.event.push("quit") end
        ce:keypressed(key)
end

function love.textinput(t)
        ce:textinput(t)
end