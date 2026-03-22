export type RunningStatus = "None" | "Starting" | "Started" | "Stopping" | "Stopped"

local RunningStatus = {
	None = "None" :: "None",
	Starting = "Starting" :: "Starting",
	Started = "Started" :: "Started",
	Stopping = "Stopping" :: "Stopping",
	Stopped = "Stopped" :: "Stopped",
}

return RunningStatus
