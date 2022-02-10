class Dot(object):
    def __init__(self, data):
        for name, value in data.items():
            setattr(self, name, self._wrap(value))

    def _wrap(self, value):
        #If it's one of the following values: tupel,list,set,frozenset
        if isinstance(value, (tuple, list, set, frozenset)): 
            #wrap it with list of 
            return type(value)([self._wrap(v) for v in value])
        else:
            return Struct(value) if isinstance(value, dict) else value