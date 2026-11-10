package handlers

import (
	"errors"

	"github.com/labstack/echo/v4"

	"aniting/internal/systeminfo"
)

// HandleGetGPUSettings
//
//	@summary returns the host GPUs and the per-app GPU preference.
//	@desc Windows exposes a per-app "high performance" preference; Linux reports
//	@desc it as unsupported (hybrid setups need DRI_PRIME at launch).
//	@route /api/v1/system/gpu [GET]
//	@returns systeminfo.GPUSettings
func (h *Handler) HandleGetGPUSettings(c echo.Context) error {
	return h.RespondWithData(c, systeminfo.Settings())
}

// HandleSetGPUPreference
//
//	@summary stores the per-app GPU preference.
//	@desc mode: "auto" | "high" | "power". Takes effect the next time the app
//	@desc starts, because the OS picks the adapter at process creation.
//	@route /api/v1/system/gpu/preference [PATCH]
//	@returns systeminfo.GPUSettings
func (h *Handler) HandleSetGPUPreference(c echo.Context) error {
	type body struct {
		Mode string `json:"mode"`
	}

	var b body
	if err := c.Bind(&b); err != nil {
		return h.RespondWithError(c, err)
	}

	switch b.Mode {
	case systeminfo.GPUModeAuto, systeminfo.GPUModeHigh, systeminfo.GPUModePower:
	default:
		return h.RespondWithError(c, errors.New("invalid gpu preference mode"))
	}

	if err := systeminfo.SetPreference(b.Mode); err != nil {
		return h.RespondWithError(c, err)
	}

	return h.RespondWithData(c, systeminfo.Settings())
}
