local quadtree = {}
local mt = { __index = quadtree }
local MAX_DEPTH = 5

local function TabNum( tab )
    assert(type(tab) == "table", "Error, tab is not table")
    local num = 0
    for _,v in pairs(tab) do
        if v ~= nil then
            num = num + 1
        end
    end
    return num
end

function quadtree.new (l, b, r, t, p)
    local tmpDepth = 0
    if p then
        tmpDepth = p.depth + 1
    end
    return setmetatable ({
        left = l,
        bottom = b,
        right = r,
        top = t,
        object = {},
        children = {},
        parent = p,
        depth = tmpDepth,
    }, mt)
end
function quadtree:genChildren ()
    if self.depth >= MAX_DEPTH then
        return
    end

    local left = self.left
    local right = self.right
    local top = self.top
    local bottom = self.bottom
    local centerx = (left + right) // 2
    local centery = (top + bottom) // 2

    local tree1 = quadtree.new (left, centery, centerx, top, self)
    if tree1 then
        tree1:genChildren()
    end
    local tree2 = quadtree.new (centerx, centery, right, top, self)
    if tree2 then
        tree2:genChildren()
    end
    local tree3 = quadtree.new (left, bottom, centerx, centery, self)
    if tree3 then
        tree3:genChildren()
    end
    local tree4 = quadtree.new (centerx, bottom, right, centery, self)
    if tree4 then
        tree4:genChildren()
    end

    self.children = { tree1, tree2, tree3, tree4}
end

function quadtree:insert (id, x, y)
    if x < self.left or x > self.right or y > self.top or y < self.bottom then
        return
    end

    if #self.children > 0 then
        local ret
        for _, v in pairs (self.children) do
            ret = v:insert (id, x, y)
            if ret then return ret end
        end
    else
        self.object[id] = { x = x, y = y }
        -- dump(self, "insert in tree")
        return self
    end
end

function quadtree:remove (id)
    if TabNum(self.object) > 0 then
        if self.object[id] ~= nil then
            self.object[id] = nil
            return true
        end
    elseif #self.children > 0 then
        for _, v in pairs (self.children) do
            if v:remove (id) then return true end
        end
    end
end

function quadtree:query (id, left, bottom, right, top, result)
    if left > self.right or right < self.left or top < self.bottom or bottom > self.top then return end

    if #self.children > 0 then
        for _, v in pairs (self.children) do
            v:query (id, left, bottom, right, top, result)
        end
    else

        for k, v in pairs (self.object) do
            if k ~= id and v.x > left and v.x < right and v.y < top and v.y > bottom then
                table.insert (result, k)
            end
        end
    end
end

return quadtree
