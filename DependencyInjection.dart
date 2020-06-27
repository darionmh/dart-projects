import 'dart:mirrors';

void main() {
  DependencyInjection inj = DependencyInjection();

  inj.preload([Endpoint]);

  print(inj.dependencies);
}

class DependencyInjection {
  List<dynamic> dependencies = [];

  void preload(List<Type> types) {
    types.forEach((t) => get(t));
  }

  dynamic get(Type type) {
    if(!_isInjectable(reflectType(type))){
      throw ("Dependency that is not @Injectable: ${type}");
    }
    return _createType(type, []);
  }

  dynamic _createType(Type type, List<Type> parents) {
    var d = dependencies.firstWhere((d) => d.runtimeType == type,
        orElse: () => null);
    if (d == null) {
      List<Type> currParents = List.from(parents);
      currParents.add(type);

      List<ParameterMirror> paramMirrors =
          _getRequiredParams(reflectClass(type));
      List params = paramMirrors.map((p) {
        Type t = p.type.reflectedType;
        if (currParents.contains(t)) {
          throw ("Recursive dependency");
        }

        if (!_isInjectable(p.type)) {
          throw ("Dependency that is not @Injectable: ${t}");
        }

        return _createType(t, currParents);
      }).toList();

      d = _instantiateType(type, const Symbol(''), params);
      dependencies.add(d);
    }
    return d;
  }

  dynamic _instantiateType(Type type, Symbol constructorName, List positional,
      [Map named]) {
    return reflectClass(type)
        .newInstance(constructorName, positional, named)
        .reflectee;
  }

  dynamic _instantiateClass(
      ClassMirror mirror, Symbol constructorName, List positional,
      [Map named]) {
    return mirror.newInstance(constructorName, positional, named).reflectee;
  }

  bool _isInjectable(ClassMirror mirror) {
    final ClassMirror someAnnotationMirror = reflectClass(Injectable);
    final annotationInstanceMirror = mirror.metadata
        .firstWhere((d) => d.type == someAnnotationMirror, orElse: () => null);

    return annotationInstanceMirror != null;
  }

  List<ParameterMirror> _getRequiredParams(ClassMirror mirror) {
    MethodMirror ctor = mirror.declarations.values.firstWhere(
        (declare) => declare is MethodMirror && declare.isConstructor);
    return ctor.parameters;
  }
}

@Injectable()
class Endpoint {
  OtherClass i;
  Endpoint(this.i);

  handle() => print('Request received');
}

@Injectable()
class OtherClass {
  Foo f;
  Bar b;
  OtherClass(this.f, this.b);
}

@Injectable()
class Foo {}

@Injectable()
class Bar {}

class Injectable {
  const Injectable();
}
