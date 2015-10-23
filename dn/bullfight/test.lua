local casino = require "poker"

local function TwoPlayerCompare(plr1, plr2)
	local score1 = {uid = plr2.uid, firstadd = 0, secadd = 0, thirdadd = 0, spadd = 0, totaladd = 0}
	local score2 = {uid = plr1.uid, firstadd = 0, secadd = 0, thirdadd = 0, spadd = 0, totaladd = 0}
	if not plr1.choicesptype then
		plr1.sptype = 0
	end
	if not plr2.choicesptype then
		plr2.sptype = 0
	end

	if plr1.sptype ~= 0 or plr2.sptype ~= 0 then
		if plr1.sptype > plr2.sptype then
			plr1.totaladd = plr1.totaladd + types.SP_TYPE_ADD[plr1.sptype]
			plr2.totaladd = plr2.totaladd - types.SP_TYPE_ADD[plr1.sptype]
			score1.spadd = types.SP_TYPE_ADD[plr1.sptype]
			score2.spadd = 0 - types.SP_TYPE_ADD[plr1.sptype]
		elseif plr1.sptype < plr2.sptype then
			plr1.totaladd = plr1.totaladd - types.SP_TYPE_ADD[plr2.sptype]
			plr2.totaladd = plr2.totaladd + types.SP_TYPE_ADD[plr2.sptype]
			score1.spadd = 0 - types.SP_TYPE_ADD[plr1.sptype]
			score2.spadd = types.SP_TYPE_ADD[plr1.sptype]
		end
	else
		local c11 = {}
		local c12 = {}
		local c13 = {}
		local c21 = {}
		local c22 = {}
		local c23 = {}
		for i = 1, 13 do
			if i < 6 then
				table.insert(c13, plr1.choicecards[i])
				table.insert(c23, plr2.choicecards[i])
			elseif i < 11 then
				table.insert(c12, plr1.choicecards[i])
				table.insert(c22, plr2.choicecards[i])
			else
				table.insert(c11, plr1.choicecards[i])
				table.insert(c21, plr2.choicecards[i])
			end
		end
		local res1 = casino.CompareCards(c11, plr1.firsttype, c21, plr2.firsttype)
		local res2 = casino.CompareCards(c12, plr1.sectype, c22, plr2.sectype)
		local res3 = casino.CompareCards(c13, plr1.thirdtype, c23, plr2.thirdtype)
		print("----------------", res1, res2, res3)
		if 1 == res1 then
			score1.firstadd = casino.GetScore(plr1.firsttype, 1)
			score2.firstadd = 0 - score1.firstadd
		elseif -1 == res1 then
			score2.firstadd = casino.GetScore(plr2.firsttype, 1)
			score1.firstadd = 0 - score2.firstadd
		end
		if 1 == res2 then
			score1.secadd = casino.GetScore(plr1.sectype, 2)
			score2.secadd = 0 - score1.secadd
		elseif -1 == res2 then
			score2.secadd =  casino.GetScore(plr2.sectype, 2)
			score1.secadd = 0 - score2.secadd
		end
		if 1 == res3 then
			score1.thirdadd =  casino.GetScore(plr1.thirdtype, 3)
			score2.thirdadd = 0 - score1.thirdadd
		elseif -1 == res3 then
			score2.thirdadd =  casino.GetScore(plr2.thirdtype, 3)
			score1.thirdadd = 0 - score2.thirdadd
		end
		--[[
		if res1 == 1 and res2 == 1 and res3 == 1 then
			--table.insert(plr1.shoot, plr2.uid)
			score1.totaladd = (score1.firstadd + score1.secadd + score1.thirdadd) * 2
			score2.totaladd = (score2.firstadd + score2.secadd + score2.thirdadd) * 2
		elseif res1 == -1 and res2 == -1 and res3 == -1 then
		--	table.insert(plr2.shoot, plr1.uid)
			score1.totaladd = (score1.firstadd + score1.secadd + score1.thirdadd) * 2
			score2.totaladd = (score2.firstadd + score2.secadd + score2.thirdadd) * 2
		else
			score1.totaladd = score1.firstadd + score1.secadd + score1.thirdadd
			score2.totaladd = score2.firstadd + score2.secadd + score2.thirdadd
		end
		plr1.totaladd = plr1.totaladd + score1.totaladd
		plr2.totaladd = plr2.totaladd + score2.totaladd
		plr1.nomaladd = plr1.nomaladd + res1 + res2 + res3
		plr2.nomaladd = plr2.nomaladd - res1 - res2 - res3]]
	end
--	table.insert(plr1.scoredetail, score1)
--	table.insert(plr2.scoredetail, score2)
	return score1.firstadd, score1.secadd, score1.thirdadd
end

function check(filename)
	local fd = io.open(filename)
	if fd == nil then
		return
	end
	local n = 0
	for line in fd:lines() do
		n = n + 1
		 local cards1 = {}
		 local cards2 = {}
		 local start = 1
		 for i = 1, 13 do
			 local _, last, p, s = string.find(line, "(%d+) (%d+) ", start)
			 p = tonumber(p)
			 s = tonumber(s)
			 start = last
			 local card = {point = p, suit = s}
			 table.insert(cards1, card)
		 end
		 local _, last, third1, sec1, first1 = string.find(line, "(%d+) (%d+) (%d+) ", start)
		 third1 = tonumber(third1)
		 sec1 = tonumber(sec1)
		 first1 = tonumber(first1)
		 start = last
		 for i = 1, 13 do
			 local _, last, p, s = string.find(line, "(%d+) (%d+) ", start)
			 p = tonumber(p)
			 s = tonumber(s)
			 start = last
			 local card = {point = p, suit = s}
			 table.insert(cards2, card)
		 end
		 local _, last, third2, sec2, first2 = string.find(line, "(%d+) (%d+) (%d+) ", start)
		 third2 = tonumber(third2)
		 sec2 = tonumber(sec2)
		 first2 = tonumber(first2)
		 start = last
		 --print("====================", third2, sec2, first2)

		 local _, _, fadd, sadd, tadd = string.find(line, "([+-]?%d+) ([+-]?%d+) ([+-]?%d+)", start)
		-- print("add=====", fadd, sadd, tadd)
		 fadd = tonumber(fadd)
		 sadd = tonumber(sadd)
		 tadd = tonumber(tadd)


		 local c11 = {}
		 local c12 = {}
		 local c13 = {}
		 local c21 = {}
		 local c22 = {}
		 local c23 = {}
		 for i = 1, 13 do
			 if i <= 5 then
				table.insert(c13, cards1[i])
				table.insert(c23, cards2[i])
			elseif i <= 10 then
				table.insert(c12, cards1[i])
				table.insert(c22, cards2[i])
			else
				table.insert(c11, cards1[i])
				table.insert(c21, cards2[i])
			end
		 end
		 local type1 = casino.GetThreeCardsType(c11)
		 local type2 = casino.GetFiveCardsType(c12)
		 local type3 = casino.GetFiveCardsType(c13)
	 	 if third1 ~= type3 then
			 print("error, real type: ", third1, "wrong type", type3 )
			 for k, v in pairs(c3) do
				 print(v.point, v.suit)
			 end
			 return
		 elseif sec1 ~= type2 then
			 print("error, real type: ", sec1, "wrong type", type2 )
			 for k, v in pairs(c2) do
				 print(v.point, v.suit)
			 end
			 return
		 elseif first1 ~= type1 then
			 print("error, real type: ", first1, "wrong type", type1 )
			 for k, v in pairs(c1) do
				 print(v.point, v.suit)
			 end
			 return
		 end
		 local plr1 = {uid = 1, sptype = 0, choicecards = cards1, firsttype = first1, sectype = sec1, thirdtype = third1}
		 local plr2 = {uid = 2, sptype = 0, choicecards = cards2, firsttype = first2, sectype = sec2, thirdtype = third2}
		 local res1, res2, res3 = TwoPlayerCompare(plr1, plr2)
		 --[[
		 local res1 = casino.CompareCards(c11,first1, c21, first2)  
		 local res2 = casino.CompareCards(c12, sec1, c22, sec2)
		 local res3 = casino.CompareCards(c13, third1, c23, third2)]]
		 if res1 ~= fadd or res2 ~= sadd or res3 ~= tadd then
			 print("compare error", n)
			 casino.printcards(cards1)
			 print("cards 2")
			 casino.printcards(cards2)
			 print("end:")
			 print(res1, res2, res3,"right:", fadd, sadd, tadd)
			 return
		 end
	 end
end

local function check2()
	for i = 1, 100000 do
		if i % 100 == 0 then
			print("curround:", i)
		end
		local poker = {}
		casino.InitPoker(poker)
		local card1 = {suit = 5; point = 15}
		local card2 = {suit = 5; point = 16}
		casino.DisCard(poker, card1)
		casino.DisCard(poker, card2)
		casino.Shulff(poker)
		local cards, pos = casino.PopCards(poker, 13, 1)
		local alltypes = {}
		local res =	casino.GetTopNPokerType(cards, 5, alltypes)
		if res == false then
			return
		end
		for i, j in pairs(alltypes) do
			local type1 = casino.GetThreeCardsType(j.firstcards)
			local type2 = casino.GetFiveCardsType(j.seccards)
			local type3 = casino.GetFiveCardsType(j.thirdcards)
			if j.thirdtype ~= type3 then
				print("error, 3, real type: ", type3, "wrong type", j.thirdtype )
				for k, v in pairs(j.thirdcards) do
					print(v.point, v.suit)
				end
				print("-------")
				for k, v in pairs(j.seccards) do
					print(v.point, v.suit)
				end
				print("-------")
				for k, v in pairs(j.firstcards) do
					print(v.point, v.suit)
				end
				print("get poker")
				for k, v in pairs(cards) do
					print(v.point, v.suit)
				end
				return
			elseif j.sectype ~= type2 then
				print("error, 2, real type: ", type2, "wrong type", j.sectype )
				for k, v in pairs(j.thirdcards) do
					print(v.point, v.suit)
				end
				print("-------")
				for k, v in pairs(j.seccards) do
					print(v.point, v.suit)
				end
				print("-------")
				for k, v in pairs(j.firstcards) do
					print(v.point, v.suit)
				end
				print("get poker")
				for k, v in pairs(cards) do
					print(v.point, v.suit)
				end
				return
			elseif j.firsttype ~= type1 then
				print("error, 1, real type: ", type1, "wrong type", j.firsttype )
				for k, v in pairs(j.thirdcards) do
					print(v.point, v.suit)
				end
				print("-------")
				for k, v in pairs(j.seccards) do
					print(v.point, v.suit)
				end
				print("-------")
				for k, v in pairs(j.firstcards) do
					print(v.point, v.suit)
				end
				print("get poker")
				for k, v in pairs(cards) do
					print(v.point, v.suit)
				end
				return
			end
		end
	end
end

function check3()
	local alltypes = {}
	local cards={{point=13,suit=3},{point=10,suit=3},{point=9,suit=3},{point=8,suit=3},{point=6,suit=3},
			{point=12,suit=2},{point=12,suit=4},{point=12,suit=3},{point=11,suit=4},{point=5,suit=2},
			{point=8,suit=1},{point=14,suit=3},{point=4,suit=2}}
	GetTopNPokerType(cards, 5, alltypes)
	for k, v in pairs(alltypes) do
		local type1 = GetThreeCardsType(v.firstcards)
		local type2 = GetFiveCardsType(v.seccards)
		local type3 = GetFiveCardsType(v.thirdcards)
		if v.firsttype ~= type1 or v.sectype ~= type2 or v.thirdtype ~= type3 then
			print("Get wrong", type1,type2, type3, " wrong type", v.firsttype, v.sectype, v.thirdtype)
		end
	end
end

function check4()
	for x = 1, 100000 do
		local poker = {}
		InitPoker(poker)
		local card1 = {suit = 5; point = 15}
		local card2 = {suit = 5; point = 16}
		DisCard(poker, card1)
		DisCard(poker, card2)
		Shulff(poker)
		for k, v in pairs(poker) do
			for i = k + 1, #poker do
				if v.point == poker[i].point and v.suit == poker[i].suit then
					print("same card")
				end
			end
		end
	end
end

function check5()
	for x = 1, 100000 do
		local poker = {}
		InitPoker(poker)
		local card1 = {suit = 5; point = 15}
		local card2 = {suit = 5; point = 16}
		DisCard(poker, card1)
		DisCard(poker, card2)
		Shulff(poker)
		local cards, pos = PopCards(poker, 13, 1)
		local alltypes = {}
		local ac = {}
		local retcards = {}
	    AdjustCards(cards, ac)
		GetTypeForSuit(ac, retcards)
		print(#retcards)
		for k, v in pairs(retcards) do
			local resc = {}
			CopyCards(cards, resc)
			for a1, a2 in pairs(v.cards) do
				print(a2.point, a2.suit)
			end
			DisCards(resc, v.cards)
			for a, b in pairs(resc) do
				for c, d in pairs(v.cards) do
					if b.point == d.point and b.suit == d.suit then
						print("the same card")
					end
				end
			end
		end
	end
end

function check6()
	for x = 1, 100000 do
		local poker = {}
		InitPoker(poker)
		local card1 = {suit = 5; point = 15}
		local card2 = {suit = 5; point = 16}
		DisCard(poker, card1)
		DisCard(poker, card2)
		Shulff(poker)
		local cards, pos = PopCards(poker, 13, 1)
		local c2 = {}
		CopyCards(cards, c2)
		if #cards ~= #c2 then
			print("size error")
		end
		for i = 1, #cards do
			if cards[i].point ~= c2[i].point or cards[i].suit ~= c2[i].suit then
				print("copy error")
				return false
			end
		end
	end
	print("test succ")
end


function check7(filename)
	local fd = io.open(filename)
	if fd == nil then
		return
	end
	for line in fd:lines() do
		 local cards = {}
		 local start = 1
		 for i = 1, 13 do
			 local _, last, p, s = string.find(line, "(%d+) (%d+) ", start)
			 p = tonumber(p)
			 s = tonumber(s)
			 start = last
			 local card = {point = p, suit = s}
			 table.insert(cards, card)
		 end
		 local _, _, type = string.find(line, "(%d+)", start)
		 type = tonumber(type)
		 local retcards = {}
		 local t1 = casino.GetSPType(cards, retcards)
		 if t1 ~= type then
			 print("type error right:", type, "error type", t1)
			 casino.printcards(cards)
			 print("choice cards")
			 casino.printcards(retcards)
			 return 0
		 end
		 if type ~= 0 and casino.HasCards(retcards, cards) == false then
			 print("cards error, right:", type)
			 casino.printcards(cards)
			 print("error cards:")
			 casino.printcards(retcards)
			 return 0
		 end
	 end
 end

function FlushPerm(cards, num, curnum, getcards, allperm, types)
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
			local retcards = {}
			local t = casino.GetSPType(gc2, retcards)
			if types[t] then
				types[t] = types[t] + 1
			else
				types[t] = 1
			end
			--table.insert(allperm, gc2)
		else
			FlushPerm(c2, num, cn2, gc2, allperm, types)
		end                                                           
	end
end
 local function GetAllTypes()
	local poker = {}
	casino.InitPoker(poker)
	casino.DisCard(poker, {point = 15, suit = 5})
	casino.DisCard(poker, {point = 16, suit = 5})
	local getcards = {}
	local perm = {}
	local types = {}
	local gc = {}
	FlushPerm(poker, 13, 0, gc, perm, types)
	local total = 0
	for k, v in pairs(types) do
		total = total + v
	end
	print("all:", total)
	for k, v in pairs(types) do
		print(k, v, v/total)
	end
end

local function CheckSPType()
	local stime = os.time()
	local poker = {}
	casino.InitPoker(poker)
	casino.DisCard(poker, {point = 15, suit = 5})
	casino.DisCard(poker, {point = 16, suit = 5})
	local sptype = {}
	for i = 1, 10000000 do
		if i % 10000 == 0 then
			print(i, os.time() - stime)
		end
		local p = 1
		casino.Shuffle(poker)
		for j = 1, 4 do
			local cards, pos = casino.PopCards(poker, 13, p)
			p = pos
			local retcards = {}
			local t = casino.GetSPType(cards, retcards)
			if not sptype[t] then
				sptype[t] = 1
			else
				sptype[t] = sptype[t] + 1
			end
		end
	end
	for k, v in pairs(sptype) do
		print(k, v)
	end
end

local function test1()
		c11 = {[1] = {point = 13, suit = 2}, [2] = {point = 9, suit = 3}, [3] = {point = 4, suit = 2}}
		c21 = {[1] = {point = 12, suit = 4}, [2] = {point = 7, suit = 3}, [3] = {point = 3, suit = 3}}
		local res1 = casino.CompareCards(c11, 1, c21, 1)
		print(res1)
	end
--	test1()

local function bftest()
	local c =  {{point = 7, suit = 1}, {point = 9, suit = 4}, 
			{point = 4, suit = 4}, {point = 13, suit = 2},
			{point = 10, suit = 1}}
	local c1 = {{suit=3, point=5},{suit=1, point=7},{suit=3, point=8},{suit=1, point=12},{suit=3, point=11}}
	local c2 = {{point=3, suit=4},{point=9, suit=1},{point=5, suit=2},{point=4, suit=4},{point=6, suit=1}}
	local ret = {}
	print(casino.GetBFType(c2, ret))
end

bftest()

--CheckSPType()
--GetAllTypes()

-- check7("moneylog.log")

--check6()
--check5()
	--check4()

--check3()
		

--check2()

--check("moneylog.log")
