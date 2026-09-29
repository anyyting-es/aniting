package extension_repo

import (
	"fmt"
	gojautil "seanime/internal/util/goja"
	"strings"
	"sync"

	"github.com/dop251/goja"
)

type sharedModules struct {
	mu       sync.RWMutex
	programs map[string]*goja.Program
}

func newSharedModules() *sharedModules {
	return &sharedModules{
		programs: make(map[string]*goja.Program),
	}
}

func (s *sharedModules) Bind(vm *goja.Runtime, allowDefine bool) {
	sharedObj := vm.NewObject()

	if allowDefine {
		_ = sharedObj.Set("define", func(call goja.FunctionCall) goja.Value {
			return s.define(vm, call)
		})
	}

	_ = sharedObj.Set("use", func(call goja.FunctionCall) goja.Value {
		return s.use(vm, call)
	})

	_ = vm.Set("$shared", sharedObj)
}

func (s *sharedModules) define(vm *goja.Runtime, call goja.FunctionCall) goja.Value {
	name := strings.TrimSpace(gojautil.ExpectStringArg(vm, call, 0))
	_ = gojautil.ExpectFunctionArg(vm, call, 1)

	if err := s.register(name, call.Argument(1).String()); err != nil {
		panic(vm.NewTypeError(err.Error()))
	}

	return goja.Undefined()
}

func (s *sharedModules) use(vm *goja.Runtime, call goja.FunctionCall) goja.Value {
	name := strings.TrimSpace(gojautil.ExpectStringArg(vm, call, 0))

	program, err := s.get(name)
	if err != nil {
		panic(vm.NewTypeError(err.Error()))
	}

	value, err := vm.RunProgram(program)
	if err != nil {
		panic(err)
	}

	if value == nil || goja.IsUndefined(value) || goja.IsNull(value) {
		panic(vm.NewTypeError(fmt.Sprintf("shared module %q must return a value", name)))
	}

	return value
}

func (s *sharedModules) register(name, source string) error {
	if name == "" {
		return fmt.Errorf("shared module name is required")
	}

	source = strings.TrimSpace(source)
	source = strings.TrimRight(source, "; \t\r\n")

	if source == "" {
		return fmt.Errorf("shared module %q factory is required", name)
	}

	program, err := compileSharedModuleSource(source)
	if err != nil {
		return fmt.Errorf("failed to compile shared module %q: %w", name, err)
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.programs[name]; exists {
		return fmt.Errorf("shared module %q already exists", name)
	}

	s.programs[name] = program
	return nil
}

func compileSharedModuleSource(source string) (*goja.Program, error) {
	program, err := goja.Compile("", "("+source+").call(undefined)", true)
	if err == nil {
		return program, nil
	}

	fixedSource := fixArrowFunctionSource(source)
	if fixedSource == source {
		return nil, err
	}

	program, fixedErr := goja.Compile("", "("+fixedSource+").call(undefined)", true)
	if fixedErr != nil {
		return nil, err
	}

	return program, nil
}

func fixArrowFunctionSource(source string) string {
	if !strings.Contains(source, "=>") {
		return source
	}

	if !strings.Contains(source, "=> (") && !strings.Contains(source, "=>(") {
		return source
	}

	openParens := strings.Count(source, "(")
	closeParens := strings.Count(source, ")")
	if openParens <= closeParens {
		return source
	}

	return source + strings.Repeat(")", openParens-closeParens)
}

func (s *sharedModules) get(name string) (*goja.Program, error) {
	if name == "" {
		return nil, fmt.Errorf("shared module name is required")
	}

	s.mu.RLock()
	defer s.mu.RUnlock()

	program, ok := s.programs[name]
	if !ok {
		return nil, fmt.Errorf("shared module %q not found", name)
	}

	return program, nil
}
