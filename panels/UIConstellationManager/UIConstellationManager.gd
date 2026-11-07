# Copyright (c) 2025 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Controller, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name UIConstellationManager extends UIPanel
## UIConstellationManager to manage the Constelation Network System


## StatusLabel node for the network status
@onready var status_label: Label = %StatusLabel

## Power Button for online status
@onready var power_button: Button = %PowerButton

## SettingsManagerBlockView to display settings for the local node
@onready var local_node_settings: SettingsManagerBlockView = %LocalNodeSettings


## The Constellation network instance
var _constellation: Constellation

## SignalGroup for the Constellation instance
var _constellation_signals: SignalGroup = SignalGroup.new([], {
	"network_state_changed": _update_network_state
})
 
## Colors for each NetworkState
var _status_colors: Dictionary[NetworkHandler.NetworkState, Color] = {
	NetworkHandler.NetworkState.OFFLINE: 		ThemeManager.Colors.Statuses.Off,
	NetworkHandler.NetworkState.INITIALIZING:	ThemeManager.Colors.Statuses.Standby,
	NetworkHandler.NetworkState.BOUND: 			ThemeManager.Colors.Statuses.Standby,
	NetworkHandler.NetworkState.READY: 			ThemeManager.Colors.Statuses.Normal,
	NetworkHandler.NetworkState.SHUTTING_DOWN: 	ThemeManager.Colors.Statuses.Standby,
	NetworkHandler.NetworkState.ERROR: 			ThemeManager.Colors.Statuses.Error,
}


## init
func _init(p_uuid: String = UUID.v4(), ...p_args: Array[Variant]) -> void:
	super._init(p_uuid, p_args)
	_set_class_name("UIConstellationManager")


## Ready
func _ready() -> void:
	super._ready()
	
	_constellation = Network.get_active_handler_by_name("Constellation")
	_constellation_signals.connect_object(_constellation)
	
	_update_network_state(_constellation.get_network_state())
	local_node_settings.set_manager(_constellation.get_local_node().get_settings())


## Sets the NetworkState status label
func _update_network_state(p_network_state: NetworkHandler.NetworkState, p_errcode: Error = OK):
	status_label.text = NetworkHandler.NetworkState.keys()[p_network_state]
	status_label.modulate = ThemeManager.Colors.pastel(_status_colors[p_network_state])
	
	match p_network_state:
		NetworkHandler.NetworkState.OFFLINE:
			power_button.set_pressed_no_signal(false)
		_:
			power_button.set_pressed_no_signal(true)


## Called when the power button is pressed
func _on_power_button_toggled(p_toggled_on: bool) -> void:
	if p_toggled_on:
		_constellation.start_node()
	else: 
		_constellation.stop_node() 
