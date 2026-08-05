extends Node
class_name SaberTelemetry

enum EventType {
	HIT_CORRECT,
	HIT_INCORRECT,
	MISSED
}

var events: Array[Dictionary] = []

func record_hit(
	controller: int,
	event_type: EventType,
	position: Vector3,
	normal: Vector3,
	direction: Vector3,
	strength: float,
	alignment: float
) -> void:

	var event := {
		"time": Time.get_ticks_msec()/1000.0,
		"controller": controller,
		"type": event_type,
		"point": position,
		"normal": normal,
		"direction": direction,
		"strength": strength,
		"alignment": alignment
	}

	events.append(event)

	print("Recorded hit:")
	print(event)
