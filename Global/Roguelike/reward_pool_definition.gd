extends Resource
class_name RewardPoolDefinition

const RewardCardDefinitionScript := preload("res://Global/Roguelike/reward_card_definition.gd")

@export var cards: Array[RewardCardDefinitionScript] = []

func roll_cards(count: int, rng: RandomNumberGenerator, excluded_card_ids: Array = []) -> Array:
	if count <= 0 or cards.is_empty():
		return []

	var generator := rng if rng != null else RandomNumberGenerator.new()
	var excluded_lookup := {}
	for card_id in excluded_card_ids:
		excluded_lookup[StringName(card_id)] = true

	var available_cards: Array = cards.filter(func(card):
		return card != null and not excluded_lookup.has(card.id)
	)
	var rolled_cards: Array = []

	while rolled_cards.size() < count and not available_cards.is_empty():
		var selected_card = _pick_weighted_card(available_cards, generator)
		if selected_card == null:
			break
		rolled_cards.append(selected_card)
		available_cards.erase(selected_card)

	if rolled_cards.size() < count:
		var repeatable_cards: Array = cards.filter(func(card): return card != null)
		while rolled_cards.size() < count and not repeatable_cards.is_empty():
			var fallback_card = _pick_weighted_card(repeatable_cards, generator)
			if fallback_card == null:
				break
			rolled_cards.append(fallback_card)

	return rolled_cards

func _pick_weighted_card(source_cards: Array, rng: RandomNumberGenerator):
	var valid_cards: Array = source_cards.filter(func(card): return card != null)
	if valid_cards.is_empty():
		return null

	var total_weight := 0.0
	for card in valid_cards:
		total_weight += maxf(card.weight, 0.0)

	if total_weight <= 0.0:
		return valid_cards[rng.randi_range(0, valid_cards.size() - 1)]

	var roll := rng.randf_range(0.0, total_weight)
	var cursor := 0.0
	for card in valid_cards:
		cursor += maxf(card.weight, 0.0)
		if roll <= cursor:
			return card

	return valid_cards.back()
