# Prompt: Generar Clase GDScript para Godot 4

## Uso
Copia este prompt y remplaza los campos `[EN CORCHETES]`.

---

## Prompt

```
Eres un experto en Godot 4.6 y GDScript tipado. Estoy desarrollando un videojuego
educativo sobre ciberacoso en Godot 4.6.1.

Crea una clase GDScript para: [DESCRIPCIÓN DE LA CLASE]

Requisitos:
- Usar GDScript tipado estático (type hints en todas las variables y funciones)
- Aplicar principios POO: encapsulamiento, herencia si aplica
- Nombre de clase: [NOMBRE_CLASE]
- Extiende: [NODO_BASE] (ej: Node, CharacterBody2D, Resource)
- Debe implementar: [MÉTODOS/FUNCIONALIDADES REQUERIDAS]
- Patrón de diseño a aplicar (si aplica): [PATRÓN]

Contexto del juego:
- Godot 4.6.1, GDScript
- Videojuego 2D educativo sobre bullying/ciberacoso
- Resolución: 1280x720
- El jugador [DESCRIPCIÓN DEL ROL DEL JUGADOR EN EL JUEGO]

Formato de respuesta:
1. Código GDScript completo con docstrings
2. Breve explicación de las decisiones de diseño
3. Cómo conectar esta clase con el resto del proyecto
```

---

## Ejemplo de uso

Para crear la clase `Player`:
- Descripción: "personaje controlado por el usuario que navega escenarios escolares"
- Nombre_clase: `PlayerCharacter`
- Nodo_base: `CharacterBody2D`
- Métodos: `move()`, `interact()`, `take_damage()`, `use_item()`
- Patrón: State Machine para los estados (idle, walking, interacting, hurt)
