extends Node

signal state_changed(old_state, new_state)

enum State { MAIN_MENU, IN_GAME, PAUSED, LEVEL_UP, SHOP, VICTORY, DEFEAT }

var current_state: State = State.MAIN_MENU

func set_state(new_state: State) -> void:
	if current_state == new_state:
		return
	var old_state := current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)
