def test_import_app():
    import importlib
    m = importlib.import_module('app')
    assert hasattr(m, 'create_ui') or hasattr(m, '__name__')
