module("extensions.gulong", package.seeall)

extension = sgs.Package("gulong")

--盗帅 - 楚留香
--摸牌阶段，你可以额外随机获得一名其他角色的一张手牌
daoshuai_card = sgs.CreateSkillCard {
	filter = function(self, targets, to_select, player)
		if #targets > 0 then
			return false
		end
		if to_select:objectName() == player:objectName() then
			return false
		end
		return not to_select:isKongcheng()
	end,
	name = "daoshuai_card",
	on_effect = function(self, effect)
		local from = effect.from
		local to = effect.to
		local room = to:getRoom()
		local card_id = room:askForCardChosen(from, to, "h", "daoshuai")
		local card = sgs.Sanguosha:getCard(card_id)
		room:moveCardTo(card, from, sgs.Player_Hand, false)
		room:setEmotion(to, "bad")
		room:setEmotion(from, "good")
	end,
}
daoshuai_viewAs = sgs.CreateViewAsSkill {
	enabled_at_play = function()
		return false
	end,
	enabled_at_response = function(player, pattern)
		return pattern == "@@daoshuai"
	end,
	name = "daoshuai_viewAs",
	view_as = function()
		return daoshuai_card:clone()
	end,
}
daoshuai = sgs.CreateTriggerSkill {
	events = sgs.PhaseChange,
	name = "daoshuai",
	on_trigger = function(self, event, player, data)
		if player:getPhase() == sgs.Player_Draw then
			player:drawCards(2)
			local room = player:getRoom()
			local can_invoke = false
			local other = room:getOtherPlayers(player)
			for _, p in sgs.qlist(other) do
				if not p:isKongcheng() then
					can_invoke = true
					break
				end
			end
			if not room:askForSkillInvoke(player, "daoshuai") then
				return true
			end
			if can_invoke and room:askForUseCard(player, "@@daoshuai", "@daoshuai_card") then
				return true
			end
			return true
		end
	end,
	view_as_skill = daoshuai_viewAs,
}

--留香 - 楚留香
--锁定技，你的手牌上限始终+1
liuxiang = sgs.CreateTriggerSkill {
	events = sgs.PhaseChange,
	frequency = sgs.Skill_Compulsory,
	name = "liuxiang",
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local hcn = player:getHandcardNum()
		local hcm = player:getHp() + 1
		local pdn = hcn - hcm
		if event == sgs.PhaseChange and player:getPhase() == sgs.Player_Discard then
			if pdn > 0 then
				room:askForDiscard(player, "liuxiang", pdn, false, false)
			end
			return true
		end
	end,
}

--踏月 - 楚留香
--锁定技，当你计算与其他角色的距离时，始终-1;当其他角色计算与你的距离时，始终+1
tayue = sgs.CreateDistanceSkill {
	correct_func = function(self, from, to)
		local correct = 0
		if from:hasSkill(self:objectName()) then
			correct = -1
		end
		if to:hasSkill(self:objectName()) then
			correct = 1
		end
		return correct
	end,
	frequency=sgs.Skill_Compulsory,
	name = "tayue",
}

--灵犀 - 陆小凤
--当你成为【杀】、【决斗】、【南蛮入侵】或【万箭齐发】的目标时，你可以进行一次判定，若结果为红色，则此【杀】、【决斗】、【南蛮入侵】或【万箭齐发】对你无效
lingxi = sgs.CreateTriggerSkill {
	events = sgs.CardEffected,
	frequency = sgs.Skill_Frequency,
	name = "lingxi",
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local card = data:toCardEffect().card
		local log = sgs.LogMessage()
		log.type = "#lingxi"
		log.from = player
		log.arg = card:objectName()
		if event == sgs.CardEffected and (card:inherits("Slash") or card:inherits("Duel") or card:inherits("SavageAssault") or card:inherits("ArcheryAttack")) then
			if not room:askForSkillInvoke(player, "lingxi") then
				return false
			end
			local judge = sgs.JudgeStruct()
			judge.pattern = sgs.QRegExp("(.*):(diamond|heart):(.*)")
			judge.good = true
			judge.reason = "lingxi"
			judge.who = player
			room:judge(judge)
			if judge:isGood() then
				room:sendLog(log)
				return true
			end
		end
	end,
}

--飞刀 - 李寻欢
--锁定技，你使用的【杀】，无视角色防具
feidao = sgs.CreateTriggerSkill {
	events = sgs.CardUsed,
	frequency = sgs.Skill_Compulsory,
	name = "feidao",
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local use = data:toCardUse()
		local card = use.card
		if event == sgs.CardUsed and not player:hasFlag("feidao_used") then
			if card:inherits("Slash") then
				for _, p in sgs.qlist(use.to) do
					p:addMark("qinggang")
				end
				room:setPlayerFlag(player, "feidao_used")
				room:useCard(use, false)
				for _, p in sgs.qlist(use.to) do
					p:removeMark("qinggang")
				end
				room:setPlayerFlag(player, "-feidao_used")
				return true
			end
		end
	end,
}

--出尘 - 无花
--锁定技，你不能成为【乐不思蜀】和【兵粮寸断】的目标
chuchen = sgs.CreateProhibitSkill {
	name = "chuchen",
	is_prohibited = function(self, from, to, card)
		if (to:hasSkill(self:objectName())) then
			return card:inherits("Indulgence") or card:inherits("SupplyShortage")
		end
	end,
}

--藏富 - 霍休
--锁定技，你的手牌上限始终等于你的体力上限
cangfu = sgs.CreateTriggerSkill {
	events = sgs.PhaseChange,
	frequency = sgs.Skill_Compulsory,
	name = "cangfu",
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local hcn = player:getHandcardNum()
		local hcm = player:getMaxHp()
		local pdn = hcn - hcm
		if event == sgs.PhaseChange and player:getPhase() == sgs.Player_Discard then
			if pdn > 0 then
				room:askForDiscard(player, "cangfu", pdn, false, false)
			end
			return true
		end
	end,
}

--楚留香
chuliuxiang = sgs.General(extension, "chuliuxiang", "qun", 3, true)
chuliuxiang : addSkill(daoshuai)
chuliuxiang : addSkill(liuxiang)
--chuliuxiang : addSkill(tayue)

--陆小凤
luxiaofeng = sgs.General(extension, "luxiaofeng", "qun", 4, true)
luxiaofeng : addSkill(lingxi)

--李寻欢
lixunhuan = sgs.General(extension, "lixunhuan", "qun", 4, true)
lixunhuan : addSkill(feidao)

--无花
wuhua = sgs.General(extension, "wuhua", "qun", 4, true)
wuhua : addSkill(chuchen)

--霍休
huoxiu = sgs.General(extension, "huoxiu", "qun", 4, true)
huoxiu : addSkill(cangfu)

sgs.LoadTranslationTable {
	["gulong"] = "古龙",

		["chuliuxiang"] = "楚留香",
		["#chuliuxiang"] = "人间不见",
		["designer:chuliuxiang"] = "布景",
			["daoshuai"] = "盗帅",
			[":daoshuai"] = "摸牌阶段，你可以额外随机获得一名其他角色的一张手牌",
			["daoshuai_card"] = "盗帅",
			["@daoshuai_card"] = "盗帅",
			["liuxiang"] = "留香",
			[":liuxiang"] = "<b>锁定技</b>，你的手牌上限始终+1",

		["luxiaofeng"] = "陆小凤",
		["#luxiaofeng"] = "四条眉毛",
		["designer:luxiaofeng"] = "布景",
			["lingxi"] = "灵犀",
			[":lingxi"] = "当你成为【杀】、【决斗】、【南蛮入侵】或【万箭齐发】的目标时，你可以进行一次判定，若结果为红色，则此【杀】、【决斗】、【南蛮入侵】或【万箭齐发】对你无效",
			["#lingxi"] = "%from 使用了<b>【<font color='yellow'>灵犀</font>】</b>技能，<b>%arg</b> 无效",

		["lixunhuan"] = "李寻欢",
		["#lixunhuan"] = "探花郎",
		["designer:lixunhuan"] = "布景",
			["feidao"] = "飞刀",
			[":feidao"] = "<b>锁定技</b>，你使用的【杀】，无视角色防具",

		["wuhua"] = "无花",
		["#wuhua"] = "妙僧",
		["designer:wuhua"] = "布景",
			["chuchen"] = "出尘",
			[":chuchen"] = "<b>锁定技</b>，你不能成为【乐不思蜀】和【兵粮寸断】的目标",

		["huoxiu"] = "霍休",
		["#huoxiu"] = "富甲天下",
		["designer:huoxiu"] = "布景",
			["cangfu"] = "藏富",
			[":cangfu"] = "<b>锁定技</b>，你的手牌上限始终等于你的体力上限",
}
