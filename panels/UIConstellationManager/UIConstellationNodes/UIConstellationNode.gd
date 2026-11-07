# Copyright (c) 2025 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Controller, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name UIConstellationNodes extends PanelContainer
## UIConstellationManagerNodes


## The Table Node to show all Constellation Nods
@export var _table: Table


## Enum for each Columns
enum Columns {NAME, IP_ADDR, ROLE_FLAGS, CONNECTION_STATUS, PING, SESSION}


## The Constellation network instance
var _constellation: Constellation

## RefMap for ConstellationNode: Table.Row
var _node_rows: RefMap = RefMap.new()

## Config for each column
var _column_config: Dictionary[int, Dictionary] = {
	Columns.NAME: {"type": Data.Type.STRING},
	Columns.IP_ADDR: {"type": Data.Type.STRING},
	Columns.ROLE_FLAGS: {"type": Data.Type.BITFLAGS},
	Columns.CONNECTION_STATUS: {"type": Data.Type.ENUM},
	Columns.PING: {"type": Data.Type.FLOAT},
	Columns.SESSION: {"type": Data.Type.OBJECT},
}

## SignalGroup for Constellation
var _constellation_connections: SignalGroup = SignalGroup.new([
	_on_node_found
])

## SignalGroup for ConstellationNodes
var _node_connection: SignalGroup = SignalGroup.new([
	_on_node_delete_requested
]).set_prefix("_on_node_")


## ready
func _ready() -> void:
	_constellation = Network.get_active_handler_by_name("Constellation")
	_constellation_connections.connect_object(_constellation)
	
	for column_name: String in Columns:
		_table.add_column(column_name.capitalize(), _column_config[Columns[column_name]].type)
	
	for node: ConstellationNode in _constellation.get_all_nodes():
		_add_node(node)


## Adds a ConstellationNode to the table
func _add_node(p_node: ConstellationNode) -> bool:
	if _node_rows.has_left(p_node) or p_node.is_local():
		return false
	
	var settings: SettingsManager = p_node.get_settings()
	_node_connection.connect_object(p_node)
	
	_node_rows.map(p_node, _table.add_row({
		Columns.NAME: 				settings.get_entry("Name"),
		Columns.IP_ADDR:			settings.get_entry("IpAddress"),
		Columns.ROLE_FLAGS: 		settings.get_entry("RoleFlags"),
		Columns.CONNECTION_STATUS: 	settings.get_entry("ConnectionState"),
		Columns.PING: 				settings.get_entry("Ping"),
		Columns.SESSION: 			settings.get_entry("Session"),
	}))
	
	return true


## Removes the given ConstellationNode
func _remove_node(p_node: ConstellationNode) -> bool:
	if not _node_rows.has_left(p_node):
		return false
	
	_table.remove_row(_node_rows.left(p_node))
	_node_rows.erase_left(p_node)
	_node_connection.disconnect_object(p_node)
	
	return true


## Called when the Reload Button is pressed
func _on_reload_pressed() -> void:
	_constellation.send_discovery()


## Called when a ConstellationNode is found on the network
func _on_node_found(p_node: ConstellationNode) -> void:
	_add_node(p_node)


## Called when a ConstellationNode requests to be deleted
func _on_node_delete_requested(p_node: ConstellationNode) -> void:
	_remove_node(p_node)
