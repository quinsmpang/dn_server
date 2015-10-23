local types = require "types"
local casino = {}
local print = print
local table = table
local pairs = pairs
local string = string
local COMPARE_SUIT = false

function casino.printcards(cards)
	for k, v in pairs(cards) do
		print(v.point, v.suit)
	end
end

function casino.tostr(cards)
	local suit = {"D", "C", "H", "S"}
	local point = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"}
	local str = "[  "
	for k, v in ipairs(cards) do
		str = str..suit[v.suit]..point[v.point].."  "
	end
	str = str.."]"
	return str
end


local ComparePoint = function(card1, card2) 
	return card1.point > card2.point
end

local ComparePointAndSuit = function(card1, card2)
	return card1.point * 10 + card1.suit > card2.point * 10 + card2.suit
end

function casino.SortCards(cards)
	table.sort(cards, ComparePointAndSuit)
--	table.sort(cards, ComparePoint)
end

function casino.CheckSameCard(cards)
	for i = 1, #cards - 1 do
		for j = i + 1, #cards  do
			if cards[i].point == cards[j].point and cards[i].suit == cards[j].suit then
				return true
			end
		end
	end
	return false
end

--[[
function casino.SortCards(cards)
	if(COMPARE_SUIT) then 
		table.sort(cards, ComparePointAndSuit)
	else
		table.sort(cards, ComparePoint)
	end
end
]]
function casino.CopyCards(cards, copy)
	if cards == nil then
		return
	end
	if #copy ~= 0 then
		for i = 1, #copy do
			table.remove(copy, 1)
		end
	end
    for k, v in pairs(cards) do 
       table.insert(copy, v)
    end
end

function casino.HasCard(cards, card)
	if card == nil then
		return false
	end
	for k, v in pairs(cards) do
		if card.point == v.point and card.suit == v.suit then
			return true
		else
			return false
		end
	end
end

function casino.HasCards(cards1, cards2)--true:cards1包含cards2
	if #cards1 < #cards2 then
		return false
	end
	local c1 = {}
	local c2 = {}
	casino.CopyCards(cards1, c1)
	casino.CopyCards(cards2, c2)
	casino.SortCards(c1)
	casino.SortCards(c2)
	local pos = 1
	for k, v in pairs(c2) do
		if #c2 - k > #c1 - pos then
			return false
		end
		for i = pos, #c1 do
			if v.point == c1[i].point and v.suit == c1[i].suit then
				pos = i + 1
				break
			elseif i == #c1 then
				return false
			end
		end
	end
	return true
end

function casino.InitPoker(poker) 
	assert(type(poker) == "table")
	for i = 1, 4 do
		for j = 2, 14 do
			table.insert(poker, {suit = i, point = j})
		end
	end
	table.insert(poker, {suit = 5, point = 15})
	table.insert(poker, {suit = 5, point = 16})
end

function casino.AddOneSuit(poker, addsuit)
	assert(type(poker) == "table" and type(addsuit) == "number" and addsuit < 6 and addsuit > 0)
	if(addsuit == 5) then
		table.insert(poker, {suit = 5, point = 15})
		table.insert(poker, {suit = 5, point = 16})
	else
		for j = 2, 14 do
			table.insert(poker, {suit = addsuit, point = j})
		end
	end
end

function casino.AddOnePoint(poker, addpoint)
	assert(type(poker) == "table" and type(addpoint) == "number" and addpoint > 1 and addpoint < 15)
	for i = 1, 4 do
		table.insert(poker, {suit = i, point = addpoint})
	end
end

function casino.Shuffle(poker) 
	assert(type(poker) == "table")
	local p = {}
	for k, v in pairs(poker) do
		p[k] = v
	end
	local size = table.maxn(poker)
	math.randomseed(os.time())
	local n = size
	for i = 1, n do
		local rand = math.random(1, size)
		poker[i] = table.remove(p, rand) 
		size = size - 1
	end
end

function casino.PopCards(poker, num, pos)
	local cards = {}
	for i = 1, num do
		table.insert(cards, poker[pos])
		pos = pos + 1
	end
	return cards, pos
end 

function casino.DisCard(poker, card)
	if card ~= nil then
		for k, v in pairs(poker) do
			if card.point == v.point and card.suit == v.suit then
				table.remove(poker, k)
				break
			end
		end
	end
end

function casino.DisCards(poker, cards)
	if cards ~= nil and #cards ~= 0 then
		for k, v in pairs(cards) do
			casino.DisCard(poker, v)
		end
	end
end

function casino.AddCard(poker, card) 
	if card ~= nil then
		table.insert(poker, card)
	end
end

function casino.AddCards(poker, cards)
	if cards ~= nil and #cards ~= 0 then
		for k, v in pairs(cards) do
			table.insert(poker, v)
		end
	end
end


function casino.IsPTFlush(cards)
	assert(cards ~= nil)
	local suit = 0
	for k, v in pairs(cards) do
		if suit == 0 then
			suit = v.suit
		elseif suit ~= v.suit then
			return false
		end
	end
	return true
end

function casino.GetDifferPointNum(cards)--获取不同点数牌的数量
	local num = 1
	local point = cards[1].point
	for k, v in pairs(cards) do
		if(point ~= v.point) then
			num = num + 1
			point = v.point
		end
	end
	return num
end

function casino.IsPTStraight(cards)
	assert(cards ~= nil)
	casino.SortCards(cards)
	if(#cards ~= casino.GetDifferPointNum(cards)) then
		return false
	end
	card1 = cards[1]
	card2 = cards[#cards]
	if(card1.point == 14 and card2.point == 2) then
		card1 = cards[2]
		if(card1.point - card2.point == #cards - 2) then
			return true
		else 
			return false
		end
	else
		if(card1.point - card2.point == #cards - 1) then
			return true
		else 
			return false
		end
	end
end

function casino.IsPTFlush(cards) 
	local suit = cards[1].suit
	for k, v in pairs(cards)do
		if(suit ~= v.suit) then
			return false
		end
	end
	return true
end

function casino.GetMostPointNum(cards)--获取数量最多点数相同的牌
	local num1 = 0
	local num2 = 0
	for k,v in pairs(cards) do
		for i, j in pairs(cards) do
			if(v.point == j.point) then
				num1 = num1 + 1
			end
		end
		if(num1 > num2) then
			num2 = num1
		end
		num1 = 0
	end
	return num2
end


function casino.GetFiveCardsType(cards)--获取五张牌的牌型
	assert(#cards == 5)
	casino.SortCards(cards)
	local differnum = casino.GetDifferPointNum(cards)
	local mostnum = casino.GetMostPointNum(cards)
	if(1 == differnum) then
		return types.PT_FIVE
	elseif(2 == differnum) then
		if(4 == mostnum) then
			return types.PT_FOUR
		else
			return types.PT_FULL_HOUSE
		end
	elseif(casino.IsPTFlush(cards)) then
		if(casino.IsPTStraight(cards)) then
			return types.PT_STRAIGHT_FLUSH
		else 
			return types.PT_FLUSH
		end
	elseif(casino.IsPTStraight(cards)) then
			return types.PT_STRAIGHT
	elseif(3 == differnum) then
		if(3 == mostnum) then
			return types.PT_THREE
		else
			return types.PT_DOUBLE_PAIR
		end
	elseif(4 == differnum) then
		return types.PT_PAIR
	else
		return types.PT_SINGLE
	end
end

function casino.GetThreeCardsType(cards)  --获取三张牌的牌型
	casino.SortCards(cards)
	local differnum = casino.GetDifferPointNum(cards)
	if(1 == differnum) then
		return types.PT_THREE
	elseif(2 == differnum) then
		return types.PT_PAIR
	else return types.PT_SINGLE
	end
end

function casino.SortForCompareFive(cards, cardstype)--二三墩牌比较前排序
	assert(#cards == 5)
	if(cardstype < types.PT_SINGLE or cardstype > types.PT_FIVE) then
		cardstype = casino.GetFiveCardsType(cards)
	end
	assert(cardstype >= types.PT_SINGLE and cardstype <= types.PT_FIVE)
	casino.SortCards(cards)
	if(cardstype == types.PT_PAIR) then
		local point = 0
		for k, v in pairs(cards) do
			if(v.point == point) then
				table.insert(cards, 1, cards[k - 1])
				table.insert(cards, 1, cards[k + 1])
				table.remove(cards, k + 2)
				table.remove(cards, k + 1)
				break
			else 
				point = v.point
			end
		end
	elseif(cardstype == types.PT_DOUBLE_PAIR) then
		if(cards[1].point ~= cards[2].point) then
			table.insert(cards, cards[1])
			table.remove(cards, 1)
		elseif(cards[4].point == cards[5].point)then
			table.insert(cards, cards[3])
			table.remove(cards, 3)
		end
	elseif(cardstype == types.PT_THREE) then
		if(cards[2].point == cards[4].point) then
			table.insert(cards, 5, cards[1])
			table.remove(cards, 1)
		elseif(cards[3].point == cards[5].point)then
			table.insert(cards, cards[1])
			table.insert(cards, cards[2])
			table.remove(cards, 1)
			table.remove(cards, 1)
		end
	elseif(cardstype == types.PT_FULL_HOUSE) then
		if(cards[3].point == cards[4].point) then
			cards[1], cards[2], cards[3], cards[4], cards[5] = cards[3], cards[4], cards[5], cards[1], cards[2]
		end
	elseif(cardstype == types.PT_FOUR) then
		if(cards[1].point ~= cards[2].point) then
			cards[1], cards[2], cards[3], cards[4], cards[5] = cards[2], cards[3], cards[4], cards[5], cards[1]
		end
	end
end

function casino.SortForCompareThree(cards, cardstype)--为第一墩牌比较前的排序
	assert(3 == #cards)
	if(cardstype < types.PT_SINGLE or cardstype > types.PT_THREE) then
		cardstype = casino.GetThreeCardsType(cards)
	end
	assert(cardstype >= types.PT_SINGLE and cardstype <= types.PT_THREE)
	casino.SortCards(cards)
	if(types.PT_PAIR == cardstype) then
		if(cards[2].point == cards[3].point) then
			table.insert(cards, cards[1])
			table.remove(cards, 1)
		end
	end
end

function casino.CompareCards(cards1, type1, cards2, type2) --比较两组牌
	local cardsnum1 = #cards1
	local cardsnum2 = #cards2
	assert(cardsnum1 == cardsnum2 and (cardsnum1 == 3 or cardsnum1 == 5))
	if(cardsnum1 == 5) then
		casino.SortForCompareFive(cards1, type1)
		casino.SortForCompareFive(cards2, type2)
	elseif(cardsnum1 == 3) then
		casino.SortForCompareThree(cards1, type1)
		casino.SortForCompareThree(cards2, type2)
	end
	local result = 0
	if(type1 == type2) then
		for i = 1, #cards1 do
			if(COMPARE_SUIT) then
				if(ComparePointAndSuit(cards1[i], cards2[i])) then
					result = 1
					break
				elseif(ComparePointAndSuit(cards2[i], cards1[i])) then
					result = -1
					break
				end
			else
				if(ComparePoint(cards1[i], cards2[i])) then
					result = 1
					break
				elseif(ComparePoint(cards2[i], cards1[i])) then
					result = -1
					break
				end
			end
		end
	elseif(type1 > type2) then 
		result = 1
	else result = -1
	end
	return result
end

function casino.AdjustCards(cards, arraycards)--把牌化为数组表示
	for i = 1, 5 do
		if arraycards[i] == nil then
			arraycards[i] = {}
		end
		for j = 1, 14 do
			arraycards[i][j] = 0
		end
	end
	for k, v in pairs(cards) do
		arraycards[v.suit][v.point] = arraycards[v.suit][v.point] + 1
		arraycards[v.suit][1] = arraycards[v.suit][1] + 1
		arraycards[5][v.point] = arraycards[5][v.point] + 1
	end
end

function casino.GetTheSameCards(arraycards, count, retcards)--获取有count张点数相同的牌
	local res = false
	for k = 2, 14 do
		local v = arraycards[5][k]  
		if(count == v) then
			local c1 = {cards = {}, t = v}
			for i = 1, 4 do
				local n = arraycards[i][k]
				while(0 ~= n) do					
					local card = {point = k, suit = i}
					n = n - 1
					table.insert(c1.cards, card)
				end
			end
			table.insert(retcards, c1)
			res = true
		end
	end
	return res
end

function casino.DevideCards(arraycards, retcards)--区分对子、三张、四张、五张.单张
	for k = 2, 14 do
		local v = arraycards[5][k]
		if(v >= 1) then
			local c1 = {}
			for i = 1, 4 do
				local n = arraycards[i][k]
				while(0 ~= n) do					
					local card = {point = k, suit = i}
					n = n - 1
					table.insert(c1, card)
				end
			end
			if retcards[v] == nil then
				retcards[v] = {}
			end
			table.insert(retcards[v], c1)
		end
	end
end

function casino.GetTypeForPoint(arraycards, retcards)--按点数获取一种牌型
	local devidecards = {}
	casino.DevideCards(arraycards, devidecards) 
	if devidecards[5] or devidecards[6] or devidecards[7] or devidecards[8] then
		for i = 5, 8 do
			if devidecards[i] then
				for k, v in pairs(devidecards[i]) do	
					local c1 = {cards = {}, type = types.PT_FIVE}
					for j = 1, 5 do
						table.insert(c1.cards, v[j])
					end
				--	casino.CopyCards(v, c1.cards)
					table.insert(retcards, c1)
				end
			end
		end
	elseif devidecards[4] ~= nil then
		for k, v in pairs(devidecards[4]) do	
			local c1 = {cards = {}, type = types.PT_FOUR}
			casino.CopyCards(v, c1.cards)
			table.insert(retcards, c1)
		end
	elseif (devidecards[3] and devidecards[2]) or 
		(devidecards[3] and #devidecards[3] >= 2) then
		for k, v in pairs(devidecards[3]) do
			if devidecards[2] then
				for i, j in pairs(devidecards[2]) do
					local c1 = {cards = {}, type = types.PT_FULL_HOUSE}
					casino.CopyCards(v, c1.cards)
					casino.AddCards(c1.cards, j)
					table.insert(retcards, c1)
				end
			else
				for i, j in pairs(devidecards[3]) do
					if k ~= i then
						local c1 = {cards = {}, type = types.PT_FULL_HOUSE}
						casino.CopyCards(v, c1.cards)
						table.insert(c1.cards, j[1])
						table.insert(c1.cards, j[2])
						table.insert(retcards, c1)
					end
				end
			end
		end
	elseif devidecards[3] ~= nil then
		for k, v in pairs(devidecards[3]) do	
			local c1 = {cards = {}, type = types.PT_THREE}
			casino.CopyCards(v, c1.cards)
			table.insert(retcards, c1)
		end
	elseif devidecards[2] ~= nil then
		local num = #(devidecards[2])
		local c1 = {cards = {}, type = 0}
		if tonumber(num) == 1 then
			c1.type = types.PT_PAIR
			casino.CopyCards(devidecards[2][1], c1.cards)
		else 	
			c1.type = types.PT_DOUBLE_PAIR
			casino.CopyCards(devidecards[2][num], c1.cards)
			casino.AddCards(c1.cards, devidecards[2][1])
		end
		table.insert(retcards, c1)
	else
		local c1 = {cards = {}, type = types.PT_SINGLE}
		casino.CopyCards(devidecards[1][#devidecards[1]], c1.cards)
		table.insert(retcards, c1)
	end
end

function casino.FlushPerm(cards, num, curnum, getcards, allperm)
	local c1 = {}
	local gc1 = {}
	local cn1 = curnum
	casino.CopyCards(cards, c1)
	casino.CopyCards(getcards, gc1)
	for i = 1, #cards - (num - curnum) + 1 do
		local c2 = {}                                                 
		local gc2 = {}
		local cn2 = curnum
		casino.CopyCards(c1, c2)
		casino.CopyCards(gc1, gc2)
		table.insert(gc2, c1[1])
		table.remove(c2, 1)
		table.remove(c1, 1)
		cn2 = cn2 + 1
		if cn2 == num then
			table.insert(allperm, gc2)
		else
			casino.FlushPerm(c2, num, cn2, gc2, allperm)
		end                                                           
	end
end

function casino.GetTypeForSuit(arraycards, retcards)--按花色获取一种牌型
	local perm = {}
	for i = 1, 4 do
		if arraycards[i][1] >= 5 then
			local cards = {}
			for k = 2, 14 do
				local n = arraycards[i][k]
			    while(0 ~= n) do                                      
					local card = {point = k, suit = i}
					n = n - 1
					table.insert(cards, card)
			    end
			end
			local gc = {}
			casino.FlushPerm(cards, 5, 0, gc, perm)
		end
	end
	if #perm ~= 0 then
		for k, v in pairs(perm) do
			if casino.IsPTStraight(v) then
				local ct = {cards = {}, type = types.PT_STRAIGHT_FLUSH}
				casino.CopyCards(v, ct.cards)
				table.insert(retcards, ct)
			else
				local ct = {cards = {}, type = types.PT_FLUSH}
				casino.CopyCards(v, ct.cards)
				table.insert(retcards, ct)
			end
		end
		return true
	end
	return false
end

function casino.StraightPerm(arraycards, start, last, curnum, getcards, allperm)
	local gc1 = {}
	casino.CopyCards(getcards, gc1)
	local cn1 = curnum
	for i = 1, 4 do
		if arraycards[i][start + cn1] ~= 0 then
			local gc2 = {}
			casino.CopyCards(gc1, gc2)
			local cn2 = cn1
			local card = {point = start + curnum, suit = i}
			table.insert(gc2, card)
			cn2 = cn2 + 1
			if last - start == cn2 - 1 then
				table.insert(allperm, gc2)
			else
				casino.StraightPerm(arraycards, start, last, cn2, gc2, allperm)
			end
		end
	end
end

function casino.GetStraight(arraycards, retcards)
	local sign1 = 0
	local sign2 = 0
	local perm = {}
	for i = 2, 14 do
		if arraycards[5][i] ~= 0 then
			if sign1 == 0 then
				sign1 = i
			else
				sign2 = i
			end
			if sign2 - sign1 + 1 >= 5 then
				for j = sign1, sign2 - 5 + 1 do
					local gc = {}
					casino.StraightPerm(arraycards, j, j + 5 - 1, 0, gc, perm)
				end
				sign1 = sign1 + 1
			end
		else
			sign1 = 0 
			sign2 = 0
		end
	end
	if arraycards[5][2] ~= 0 and arraycards[5][14] ~= 0 and 
		arraycards[5][3] ~= 0 and arraycards[5][4] ~= 0 and  arraycards[5][5] ~= 0  then --顺子 A--5
		local c1 = {}
		for i = 2, 5 do 
			for j = 1, 4 do
				if arraycards[j][i] ~= 0 then
					table.insert(c1, {point = i, suit = j})
					break
				end
			end
		end
		for j = 1, 4 do
			if arraycards[j][14] ~= 0 then
				table.insert(c1, {point = 14, suit = j})
				if #c1 == 5 then
					table.insert(perm, c1)
				end
				break
			end
		end
	end
			
	if #perm ~= 0 then
		for k, v in pairs(perm)do
			local card = {cards = {}, type = types.PT_STRAIGHT}
			if casino.IsPTFlush(v) then
				card.type = types.PT_STRAIGHT_FLUSH
			end
			casino.CopyCards(v, card.cards)
			table.insert(retcards, card)
		end
	end
end

function casino.GetFiveCards(cards, retcards)--获取2、3墩牌及牌型
	assert(#cards >= 5)
	local ac = {}
	casino.AdjustCards(cards, ac)
	casino.GetTypeForPoint(ac, retcards)
	local num = tonumber(#retcards)
	casino.GetTypeForSuit(ac, retcards)
	casino.GetStraight(ac, retcards)
end

function casino.SupplyCards(scards, rcards, num)--从scards补充num张牌到rcards
	if #rcards < num then
		for i = #rcards + 1, num do
			table.insert(rcards, scards[1])
			table.remove(scards, 1)
		end
	end
end

function casino.GetThreeCards(cards, retcards)
	local ac = {}
	local permcards = {}
	casino.AdjustCards(cards, ac)
	casino.DevideCards(ac, permcards)
	local get = false
	for i = 3, 8 do
		if permcards[i] then
			retcards.type = types.PT_THREE
			local c1 = {}
			local n = #permcards[i]
			for j = 1, 3 do
				table.insert(c1, permcards[i][n][j])
			end
			get = true
			casino.CopyCards(c1, retcards.cards)
			break
		end
	end
	if not get then
		if permcards[2] ~= nil then
			retcards.type = types.PT_PAIR
			casino.CopyCards(permcards[2][1], retcards.cards)
		else
			retcards = {cards = {cards[1], cards[2], cards[3]}, type = types.PT_SINGLE}
		end
	end
end

function casino.IsRightCardsType(c1, c2, c3, t1, t2, t3)
	if t1 == casino.GetThreeCardsType(c1) and 
		t2 == casino.GetFiveCardsType(c2) and
		t3 == casino.GetFiveCardsType(c3) and
		casino.CompareCards(c3, t3, c2, t2) >= 0 then 
			local c4 = {}
			table.insert(c4, c2[1])
			table.insert(c4, c2[2])
			table.insert(c4, c2[3])
			if casino.CompareCards(c4, t2, c1, t1) >= 0 then
				return true
			end
	end
	return false
end


function casino.CheckCardsTypes(alltypes, righttypes)
	local sign = {}
	for k, v in pairs(alltypes) do
		if casino.IsRightCardsType(v.firstcards, v.seccards, v.thirdcards, v.firsttype, v.sectype, v.thirdtype) then
			table.insert(sign, k)
		end
	end
	for k, v in pairs(sign) do
		table.insert(righttypes, alltypes[v])
	end
end

function casino.GetScore(type, addr)
	if addr == 1 then
		if type == types.PT_THREE then
			return 1 + types.FIRST_PT_THREE
		end
	elseif addr == 2 then
		if type == types.PT_FULL_HOUSE then
			return 1 + types.SEC_PT_FULL_HOUSE
		elseif type == types.PT_FOUR then
			return 1 + types.SEC_PT_FOUR
		elseif type == types.PT_STRAIGHT_FLUSH then
			return 1 + types.SEC_PT_STRAIGHT_FLUSH
		elseif type == types.PT_FIVE then
			return 1 + types.SEC_PT_FIVE
		end
	elseif addr == 3 then
		if type == types.PT_FOUR then
			return 1 + types.THIRD_PT_FOUR
		elseif type == types.PT_STRAIGHT_FLUSH then
			return 1 + types.THIRD_PT_STRAIGHT_FLUSH
		elseif type == types.PT_FIVE then
			return 1 + types.THIRD_PT_FIVE
		end
	end
	return 1
end

local SortCardTypes = function(ct1, ct2)
	local score1 = ct1.firsttype + ct1.sectype + ct1.thirdtype
	local score2 = ct2.firsttype + ct2.sectype + ct2.thirdtype
	score1 = score1 + casino.GetScore(ct1.firsttype, 1)
	score1 = score1 + casino.GetScore(ct1.sectype, 2)
	score1 = score1 + casino.GetScore(ct1.thirdtype, 3)
	score2 = score2 + casino.GetScore(ct2.firsttype, 1)
	score2 = score2 + casino.GetScore(ct2.sectype, 2)
	score2 = score2 + casino.GetScore(ct2.thirdtype, 3)
	if score1 == score2 then
		return ct1.thirdtype > ct2.thirdtype
	else
		return score1 > score2
	end
end

function casino.GetTopNPokerType(cards, n, rettypes)--获取排列前n种牌型排列
	assert(cards ~= nil)
	--assert(#cards == 13)
	local alltypes = {}
	local thirdct = {}
	casino.GetFiveCards(cards, thirdct)
	for k, v in pairs(thirdct) do
		local c1 = {}
		casino.CopyCards(cards, c1)
		casino.DisCards(c1, v.cards)
		local secct = {}
		casino.GetFiveCards(c1, secct)
		for i, j in pairs(secct) do
			if v.type >= j.type then
				local c2 = {}
				casino.CopyCards(c1, c2)
				casino.DisCards(c2, j.cards)
				local firstct = {cards = {}, type = 0}
				casino.GetThreeCards(c2, firstct)
				if firstct.type == 0 then
					firstct.type = types.PT_SINGLE
				end
				casino.DisCards(c2, firstct.cards)
				local ct = {thirdcards = {}, thirdtype = v.type, seccards = {}, sectype = j.type, firstcards = {}, firsttype = firstct.type}
				casino.CopyCards(v.cards, ct.thirdcards)
				casino.CopyCards(j.cards, ct.seccards)
				casino.CopyCards(firstct.cards, ct.firstcards)
				casino.SupplyCards(c2, ct.firstcards, 3)
				casino.SupplyCards(c2, ct.seccards, 5)
				casino.SupplyCards(c2, ct.thirdcards, 5)
				table.insert(alltypes, ct)
			end
		end
	end
	local righttypes = {}
	casino.CheckCardsTypes(alltypes, righttypes)
	table.sort(righttypes, SortCardTypes)
	local num = n 
	if(n > #righttypes) then
		num = #righttypes
	end
	for i = 1, num do
		table.insert(rettypes, righttypes[i])
	end
end

function casino.IsSPAllBig(cards, retcards)
	for k, v in pairs(cards) do
		if v.point < 8 then
			return false
		end
	end
	casino.CopyCards(cards, retcards)
	return true
end

function casino.IsSPAllSmall(cards, retcards)
	for k, v in pairs(cards) do
		if v.point > 8 then
			return false
		end
	end
	casino.CopyCards(cards, retcards)
	return true
end

function casino.IsSPAllKing(cards, retcards)
	for k, v in pairs(cards) do
		if v.point < 11 then
			return false
		end
	end
	casino.CopyCards(cards, retcards)
	return true
end

function casino.IsSPStraightFlush(arraycards, retcards)
	local cards = {}
	for i = 1, 4 do
		if arraycards[i][1] >= 13 then
			for j = 2, 14 do
				if arraycards[i][j] ~= 0 then
					local card = {point = j, suit = i}
					table.insert(cards, card)
				else
					return false
				end
			end
			casino.CopyCards(cards, retcards)
			return true
		end
	end
end

function casino.IsSPStraight(cards, retcards)
	local c1 = {}
	table.insert(c1, cards[1])
	for k, v in pairs(cards) do
		if v.point ~= c1[#c1].point then
			if v.point == c1[#c1].point - 1 then
				table.insert(c1, v)
			else 
				return false
			end
		end
	end
	if #c1 == 13 then
		casino.CopyCards(c1, retcards)
		return true
	end
end

function casino.IsSPThreeFlush(arraycards, retcards)
	for i = 1, 4 do
		local num = arraycards[i][1]
		if num ~= 3 and num ~= 5 and num ~= 8 and num ~= 10 and num ~= 0 then
			return false
		end
	end
	for i = 1, 4 do
		for j = 2, 14 do
			if arraycards[i][j] ~= 0 then
				for n = 1, arraycards[i][j] do
					local card = {point = j, suit = i}
					table.insert(retcards, card)
				end
			end
		end
	end
	return true
end

function casino.GetStraightOfFive(cards, ret)
	casino.SortCards(cards)
	local c1 = {}
	table.insert(c1, cards[1])
	for k, v in pairs(cards) do
		if v.point ~= c1[#c1].point then
			table.insert(c1, v)
		end
	end
	if c1[1].point == 14 and c1[#c1].point == 2 then
		table.insert(c1, c1[1])
	end
	for i = 1, #c1 - 4 do
		local c2 = {}
		for j = 0, 4 do
			table.insert(c2, c1[i + j])
		end
		if casino.IsPTStraight(c2) then
			table.insert(ret, c2)
		end
	end
end

function casino.IsSPThreeStraightFlush(arraycards, retcards)
	local cards = {}
	local cardsforthree = {}
	for i = 1, 4 do
		local num = arraycards[i][1]
		if num == 3 or num == 5 or num == 8 or num == 10 or num == 0 then
			local c1 = {}
			for j = 2, 14 do
				if arraycards[i][j] ~= 0 then
					for n = 1, arraycards[i][j] do
						local card = {point = j, suit = i}
						table.insert(c1, card)
					end
				end
			end
			if num == 3 or num == 5 then
				if casino.IsPTStraight(c1) then
					if num == 5 then
						casino.AddCards(cards, c1)
					else 
						casino.AddCards(cardsforthree, c1)
					end
				else 
					return false
				end
			elseif num == 8 or num == 10 then
				local c2 = {}
				casino.CopyCards(c1, c2)
				local rettype = {}
				local havefind = false
				if c2[1].point == 2 and c2[#c2].point == 14 then
					table.insert(c2, 1, c2[#c2])
				end
				for i = 1, #c2 - 4 do
					local c3 = {}
					for j = 0, 4 do
						table.insert(c3, c2[i + j])
					end
					if casino.IsPTStraight(c3) then
						local c4 = {}
						casino.CopyCards(c1, c4)
						casino.DisCards(c4, c3)
						if casino.IsPTStraight(c4) then
							casino.AddCards(cards, c3)
							casino.AddCards(cards, c4)
							havefind = true
							break
						end
					end
				end
				if havefind == false then
					return false
				end
			end
		else
			return false
		end
	end
	casino.AddCards(cards, cardsforthree)
	casino.CopyCards(cards, retcards)
	return true
end

function casino.IsSPThreeStaight(cards, retcards)
	local c1 = {}
	local ret1 = {}
	casino.CopyCards(cards, c1)
	casino.GetStraightOfFive(c1, ret1)
	if #ret1 == 0 then
		return false
	end
	for k, v in pairs(ret1) do
		local c2 = {}
		local ret2 = {} 
		casino.CopyCards(c1, c2)
		casino.DisCards(c2, v)
		casino.GetStraightOfFive(c2, ret2)
		for i, j in pairs(ret2) do
			local c3 = {}
			casino.CopyCards(c2, c3)
			casino.DisCards(c3, j)
			if casino.IsPTStraight(c3) then
				casino.CopyCards(v, retcards)
				casino.AddCards(retcards, j)
				casino.AddCards(retcards, c3)
				return true
			end
		end
	end
	return false
end

function casino.GetSPType(cards, retcards)
	casino.SortCards(cards)
	local arraycards = {}
	casino.AdjustCards(cards, arraycards)
	local devidecards = {}
	casino.DevideCards(arraycards, devidecards)
	local pairnum = 0
	local threenum = 0
	if devidecards[2] ~= nil then
		pairnum = pairnum + #devidecards[2]
	end
	if devidecards[3] ~= nil then
		pairnum = pairnum + #devidecards[3]
		threenum = #devidecards[3]
	end
	if devidecards[4] ~= nil then
		pairnum = pairnum + #devidecards[4] * 2
	end
	
	if casino.IsSPStraightFlush(arraycards, retcards) then
		return types.PT_SP_STRAIGHT_FLUSH
	elseif casino.IsSPStraight(cards, retcards) then
		return types.PT_SP_STRAIGHT
	elseif devidecards[5] and #devidecards[5] == 2 and
		devidecards[3] and #devidecards[3] == 1 then
		casino.CopyCards(cards, retcards)
		return types.PT_SP_TWO_FIVE_AND_THREE
	elseif casino.IsSPAllKing(cards, retcards) then
		return types.PT_SP_ALL_KING
	elseif casino.IsSPThreeStraightFlush(arraycards, retcards) then
		return types.PT_SP_THREE_STRAIGHT_FLUSH
	elseif devidecards[4] ~= nil and #devidecards[4] == 3 then
		casino.CopyCards(cards, retcards)
		return types.PT_SP_THREE_FOUR_OF_A_KIND
	elseif casino.IsSPAllBig(cards, retcards) then
		return types.PT_SP_ALL_BIG
	elseif casino.IsSPAllSmall(cards, retcards) then
		return types.PT_SP_ALL_SMALL
	elseif (arraycards[1][1] == 0 and arraycards[3][1] == 0) or
		(arraycards[2][1] == 0 and arraycards[4][1] == 0) then
		casino.CopyCards(cards, retcards)
		return types.PT_SP_SAME_SUIT
	elseif devidecards[3] ~= nil and #devidecards[3] == 4 then
		casino.CopyCards(cards, retcards)
		return types.PT_SP_FOUR_THREE_OF_A_KIND
	elseif pairnum - threenum == 5 and threenum == 1 then
		casino.CopyCards(cards, retcards)
		return types.PT_SP_FIVE_PAIR_AND_THREE
	elseif pairnum == 6 then
		casino.CopyCards(cards, retcards)
		return types.PT_SP_SIX_PAIRS
	elseif casino.IsSPThreeStaight(cards, retcards) then
		return types.PT_SP_THREE_STRAIGHT
	elseif casino.IsSPThreeFlush(arraycards, retcards) then
		return types.PT_SP_THREE_FLUSH
	else
		return types.PT_SP_NUNE
	end
end

function casino.IsSPTwoFiveAndThree(arraycards, retcards)
	local getthree = 0
	local getfive = 0
	local cards = {}
	for i = 2, 14 do
		local num = arraycards[5][i]
		local need = 0
		if num > 2 and num < 5 then
			if getthree == 0 then
				getthree = getthree + 1
				need = 3
			end
		elseif num > 4 and num < 8 then
			if getfive < 2 then
				need = 5
				getfive = getfive + 1
			elseif getthree == 0 then
				need = 3
				getthree = getthree + 1
			end
		elseif num == 8 then
			if getthree == 0 then
				need = need + 3
				getthree = getthree + 1
			end
			if getfive < 2 then
				need = need + 5
				getfive = getfive + 1
			end
		end
		for j = 1, 4 do
			local n = arraycards[j][i]
			while(n ~= 0 and need ~= 0) do
				table.insert(cards, {point = i, suit = j})
				need = need - 1
				n = n - 1
			end
		end
	end
	if getthree == 1 and getfive == 2 then
		casino.CopyCards(cards, retcards)
		return true
	else
		return false
	end
end

function casino.GetSPTypeForFivePlayersThreeMore(cards, retcards)
	local arraycards = {}
	casino.AdjustCards(cards, arraycards)
	if casino.IsSPStraightFlush(arraycards, retcards) then
		return types.PT_SP_STRAIGHT_FLUSH
	elseif casino.IsSPStraight(cards, retcards) then
		return types.PT_SP_STRAIGHT
	elseif casino.IsSPTwoFiveAndThree(arraycards, retcards) then
		return types.PT_SP_TWO_FIVE_AND_THREE
	else
		return types.PT_SP_NUNE
	end
end

function casino.GetSPTypeForThreeMore(cards, retcards)
	local arraycards = {}
	casino.AdjustCards(cards, arraycards)
	if casino.IsSPStraightFlush(arraycards, retcards) then
		return types.PT_SP_STRAIGHT_FLUSH
	elseif casino.IsSPStraight(cards, retcards) then
		return types.PT_SP_STRAIGHT
	else
		return types.PT_SP_NUNE
	end
end

casino.bfoption = {
	{1, 2, 3, 4, 5}, {1, 2, 4, 3, 5}, {1, 2, 5, 3, 4},
	{1, 3, 4, 2, 5}, {1, 3, 5, 2, 4}, {1, 4, 5, 2, 3},
	{2, 3, 4, 1, 5}, {2, 4, 5, 1, 3}, {2, 3, 5, 1, 4},
	{3, 4, 5, 1, 2}
}

local BFComparePointAndSuit = function(card1, card2)
	return (card1.point % 14) * 10 + card1.suit > (card2.point % 14) * 10 + card2.suit
end

function casino.BFSortCards(cards)
	table.sort(cards, BFComparePointAndSuit)
end


function casino.BFCompare(cards1, type1, cards2, type2)
	if type1 > type2 then
		return true
	elseif type1 < type2 then
		return false
	else
		casino.BFSortCards(cards1)
		casino.BFSortCards(cards2)
		return BFComparePointAndSuit(cards1[1], cards2[1])
	end
end		

function casino.GetBFType(cards, retcards)
	assert(#cards == 5)
	local bftype = 0
	local points = {}
	local add = 0
	local goldnum = 0
	local silvenum = 0
	local bomboption = {}
	for k, v in pairs (cards) do
		if not bomboption[v.point] then
			bomboption[v.point] = 1
		else
			bomboption[v.point] = bomboption[v.point] + 1
		end
		if v.point == 14 then
			table.insert(points, 1)
			add = add + 1
		elseif v.point > 10 then
			table.insert(points, 10)
			add = add + v.point
			goldnum = goldnum + 1
		else
			table.insert(points, v.point)
			add = add + v.point
			if v.point == 10 then
				silvenum = silvenum + 1
			end
		end
	end
	if add < 10 then
		casino.CopyCards(cards, retcards)
		return types.PT_ALL_SMALL_BULL
	end
	for k, v in pairs(bomboption) do
		if v == 4 then
			casino.CopyCards(cards, retcards)
			return types.PT_BOMB
		end
	end
	if goldnum == 5 then
		casino.CopyCards(cards, retcards)
		return types.PT_GOLD_BULL
	elseif goldnum + silvenum == 5 then
		casino.CopyCards(cards, retcards)
		return types.PT_SILVE_BULL
	end
	for k, v in pairs(casino.bfoption) do
		if (points[v[1]] + points[v[2]] + points[v[3]]) % 10 == 0 then
			bftype = (points[v[4]] + points[v[5]]) % 10
			if bftype == 0 then
				bftype = 10
			end
			for i, j in pairs(v) do
				table.insert(retcards, cards[j])
			end
			return bftype
		end
	end
	casino.CopyCards(cards, retcards)
	return types.PT_NO_BULL
end

return casino
