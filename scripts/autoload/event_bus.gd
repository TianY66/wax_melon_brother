extends Node

signal player_damaged(amount, current_hp, max_hp)
signal player_dead
signal player_healed(amount)
signal exp_collected(amount, current_exp, exp_to_next)
signal level_up_ready(options)
signal upgrade_applied(option)
signal enemy_dead(enemy_id, elite)
signal boss_warning(seconds_left)
signal boss_spawned
signal game_victory
signal game_defeat
signal settings_changed
