%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int yylex(void);
void yyerror(const char *s); // <--- 1. Actualizado a void y const char*

extern FILE *yyin;

#define MAX_SIMB 300
#define TIPO_VAR 0
#define TIPO_FUNC 1
#define TIPO_MACRO 2
#define TIPO_INT 0

typedef struct {
    char *nombre;
    int clase;
    int tipo_dato;
    int aridad;
    int ambito;
    int activo;
} Simbolo;

Simbolo tabla[MAX_SIMB];

int ntabla = 0;
int ambito_actual = 0;
int semantic_errors = 0;

// ==========================================
// CONTROL DE ÁMBITOS (SCOPE)
// ==========================================
void entrar_ambito() {
    ambito_actual++;
}

void salir_ambito() {
    int i; // <--- Declarar 'i' afuera
    for (i = 0; i < ntabla; i++) {
        if (tabla[i].ambito == ambito_actual) {
            tabla[i].activo = 0;
        }
    }
    ambito_actual--;
}

// ==========================================
// BÚSQUEDA EN LA TABLA DE SÍMBOLOS
// ==========================================
int buscar_simbolo_clase(char *nombre, int clase) {
    int i; // <--- Declarar 'i' afuera
    for (i = ntabla - 1; i >= 0; i--) {
        if (tabla[i].activo && tabla[i].clase == clase && strcmp(tabla[i].nombre, nombre) == 0) {
            return i;
        }
    }
    return -1;
}

int existe_en_ambito_actual(char *id) {
    int i; // <--- Declarar 'i' afuera
    for (i = 0; i < ntabla; i++) {
        if (tabla[i].activo && tabla[i].ambito == ambito_actual && strcmp(tabla[i].nombre, id) == 0) {
            return 1;
        }
    }
    return 0;
}

// ==========================================
// VALIDACIONES SEMÁNTICAS
// ==========================================
void agregar_macro(char *nombre) {
    if (buscar_simbolo_clase(nombre, TIPO_MACRO) != -1) {
        printf("Error semántico: macro '%s' ya definida\n", nombre);
        semantic_errors++;
    } else {
        tabla[ntabla].nombre = strdup(nombre);
        tabla[ntabla].clase = TIPO_MACRO;
        tabla[ntabla].tipo_dato = TIPO_INT;
        tabla[ntabla].aridad = 0;
        tabla[ntabla].ambito = 0;
        tabla[ntabla].activo = 1;
        ntabla++;
    }
}

void agregar_variable(char *nombre, int tipo) {
    if (existe_en_ambito_actual(nombre)) {
        printf("Error semántico: redeclaración de variable '%s'\n", nombre);
        semantic_errors++;
    } else {
        tabla[ntabla].nombre = strdup(nombre);
        tabla[ntabla].clase = TIPO_VAR;
        tabla[ntabla].tipo_dato = tipo;
        tabla[ntabla].aridad = 0;
        tabla[ntabla].ambito = ambito_actual;
        tabla[ntabla].activo = 1;
        ntabla++;
    }
}

void agregar_funcion(char *nombre, int aridad) {
    if (buscar_simbolo_clase(nombre, TIPO_FUNC) != -1) {
        printf("Error semántico: función '%s' ya declarada\n", nombre);
        semantic_errors++;
    } else {
        tabla[ntabla].nombre = strdup(nombre);
        tabla[ntabla].clase = TIPO_FUNC;
        tabla[ntabla].tipo_dato = TIPO_INT;
        tabla[ntabla].aridad = aridad;
        tabla[ntabla].ambito = 0; // Las funciones se registran globalmente
        tabla[ntabla].activo = 1;
        ntabla++;
    }
}

void verificar_uso_variable(char *nombre) {
    if (buscar_simbolo_clase(nombre, TIPO_VAR) == -1) {
        printf("Error semántico: variable '%s' no declarada\n", nombre);
        semantic_errors++;
    }
}

void verificar_asignacion(char *izq, char *der) {
    verificar_uso_variable(izq);
    verificar_uso_variable(der);
}

void verificar_llamada_funcion(char *nombre, int argumentos) {
    int pos = buscar_simbolo_clase(nombre, TIPO_FUNC);
    if (pos == -1) {
        printf("Error semántico: función '%s' no declarada\n", nombre);
        semantic_errors++;
    } else {
        if (tabla[pos].aridad != argumentos) {
            printf("Error semántico: función '%s' espera %d argumento(s), pero recibió %d\n", 
                   nombre, tabla[pos].aridad, argumentos);
            semantic_errors++;
        }
    }
}
%}

%union {
    char *str;
    int num;
}

%token INCLUDE DEFINE INT FUNC RETURN
%token PARIZQ PARDER LLAVEIZQ LLAVEDER PUNTOYCOMA COMA IGUAL MENOR MAYOR PUNTO
%token <str> ID NUMBER STRING_LITERAL

%type <num> lista_param argumentos lista_args

%%

program:
      elementos
      {
          printf("\nAnálisis finalizado con %d error(es) semántico(s).\n", semantic_errors);
      }
    ;

elementos:
      elementos elemento
    | /* vacío */
    ;

elemento:
      include_stmt
    | macro_stmt
    | var_global_stmt
    | funcion
    ;

include_stmt:
      INCLUDE MENOR ID PUNTO ID MAYOR
    | INCLUDE STRING_LITERAL
    ;

macro_stmt:
      DEFINE ID NUMBER
      {
          agregar_macro($2);
      }
    | DEFINE ID STRING_LITERAL
      {
          agregar_macro($2);
      }
    ;

var_global_stmt:
      INT ID PUNTOYCOMA
      {
          agregar_variable($2, TIPO_INT);
      }
    ;

funcion:
      FUNC ID PARIZQ { entrar_ambito(); } lista_param PARDER 
      { 
          // Registra la función con el total de argumentos leídos en lista_param ($5)
          agregar_funcion($2, $5); 
      } 
      bloque_funcion 
      { 
          salir_ambito(); 
      }
    ;

lista_param:
      /* vacío */
      {
          $$ = 0;
      }
    | ID
      {
          agregar_variable($1, TIPO_INT);
          $$ = 1;
      }
    | lista_param COMA ID
      {
          agregar_variable($3, TIPO_INT);
          $$ = $1 + 1;
      }
    ;

bloque_funcion:
      LLAVEIZQ instrucciones LLAVEDER
    ;

bloque:
      LLAVEIZQ
      {
          entrar_ambito();
      }
      instrucciones LLAVEDER
      {
          salir_ambito();
      }
    ;

instrucciones:
      instrucciones instruccion
    | /* vacío */
    ;

instruccion:
      INT ID PUNTOYCOMA
      {
          agregar_variable($2, TIPO_INT);
      }
    | ID IGUAL ID PUNTOYCOMA
      {
          verificar_asignacion($1, $3);
      }
    | ID PARIZQ argumentos PARDER PUNTOYCOMA
      {
          verificar_llamada_funcion($1, $3);
      }
    | RETURN ID PUNTOYCOMA
      {
          verificar_uso_variable($2);
      }
    | bloque
    ;

argumentos:
      /* vacío */
      {
          $$ = 0;
      }
    | lista_args
      {
          $$ = $1;
      }
    ;

lista_args:
      ID
      {
          verificar_uso_variable($1);
          $$ = 1;
      }
    | lista_args COMA ID
      {
          verificar_uso_variable($3);
          $$ = $1 + 1;
      }
    ;

%%

void yyerror(const char *s) {
    printf("Error sintáctico: %s\n", s);
}

int main(int argc, char **argv) {
    if (argc > 1) {
        FILE *f = fopen(argv[1], "r");
        if (!f) {
            fprintf(stderr, "No se pudo abrir el archivo %s\n", argv[1]);
            return 1;
        }
        yyin = f;
    }
    yyparse();
    return 0;
}