extends Node2D

func _ready():
	# Wait a bit before starting the dialogue to ensure everything is loaded
	await get_tree().create_timer(0.5).timeout
	
	var test_data = {
		"start": {
			"name": "村长",
			"text": "勇士，你终于醒了！村子正面临着巨大的危机，我们急需你的帮助。你能听我把话说完吗？",
			"next_id": "explain_crisis"
		},
		"explain_crisis": {
			"name": "村长",
			"text": "昨晚有一群怪物袭击了我们的仓库，抢走了所有的存粮。你愿意帮我们夺回来吗？",
			"options": [
				{"text": "没问题，包在我身上！", "next_id": "accept_quest"},
				{"text": "我还有别的事，抱歉。", "next_id": "reject_quest"}
			]
		},
		"accept_quest": {
			"name": "村长",
			"text": "太感谢了！这是我们村子祖传的宝剑，请收下它。祝你好运！",
			"next_id": ""
		},
		"reject_quest": {
			"name": "村长",
			"text": "唉，那真是太遗憾了...如果你改变主意，随时可以来找我。",
			"next_id": ""
		}
	}
	
	DialogueManager.start_dialogue(test_data)
	
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _on_dialogue_ended():
	print("Dialogue test completed!")
