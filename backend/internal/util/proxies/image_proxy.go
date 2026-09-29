package util

import (
	"encoding/json"
	"io"
	"net/http"
	"seanime/internal/security"
	"seanime/internal/util"

	"github.com/imroc/req/v3"
	"github.com/labstack/echo/v4"
)

type ImageProxy struct{}

func (ip *ImageProxy) GetImage(url string, headers map[string]string) ([]byte, string, error) {
	request := req.C().DisableAutoReadResponse().NewRequest()

	for key, value := range headers {
		request.SetHeader(key, value)
	}

	resp, err := request.Get(url)
	if err != nil {
		return nil, "", err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, "", err
	}

	return body, resp.Header.Get(echo.HeaderContentType), nil
}

func (ip *ImageProxy) setHeaders(c echo.Context, contentType string) {
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	headers := c.Response().Header()
	headers.Set(echo.HeaderContentType, contentType)
	headers.Set(echo.HeaderCacheControl, "public, max-age=31536000")
	headers.Set("Access-Control-Allow-Origin", "*")
	headers.Set("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
	headers.Set("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept")
	headers.Set("Cross-Origin-Resource-Policy", "cross-origin")
}

func (ip *ImageProxy) ProxyImage(c echo.Context) (err error) {
	defer util.HandlePanicInModuleWithError("util/ImageProxy", &err)

	url := c.QueryParam("url")
	headersJSON := c.QueryParam("headers")

	if url == "" {
		return c.String(echo.ErrBadRequest.Code, "No URL provided")
	}

	if err := security.ValidateOutboundUrl(url); err != nil {
		return c.String(http.StatusForbidden, err.Error())
	}

	headers := make(map[string]string)
	if headersJSON != "" {
		if err := json.Unmarshal([]byte(headersJSON), &headers); err != nil {
			return c.String(echo.ErrBadRequest.Code, "Error parsing headers JSON")
		}
	}

	imageBuffer, contentType, err := ip.GetImage(url, headers)
	if err != nil {
		return c.String(echo.ErrInternalServerError.Code, "Error fetching image")
	}
	ip.setHeaders(c, contentType)

	return c.Blob(http.StatusOK, c.Response().Header().Get(echo.HeaderContentType), imageBuffer)
}
