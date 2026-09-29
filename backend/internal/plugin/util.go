package plugin

import "github.com/goccy/go-json"

func cloneRefValue(value interface{}) interface{} {
	switch value.(type) {
	case nil,
		bool,
		string,
		int,
		int8,
		int16,
		int32,
		int64,
		uint,
		uint8,
		uint16,
		uint32,
		uint64,
		uintptr,
		float32,
		float64,
		json.Number:
		return value
	}

	bs, err := json.Marshal(value)
	if err != nil {
		return value
	}

	var cloned interface{}
	if err := json.Unmarshal(bs, &cloned); err != nil {
		return value
	}

	return cloned
}

func cloneValueT[T any](value T) T {
	cloned, ok := cloneRefValue(value).(T)
	if ok {
		return cloned
	}

	return value
}
