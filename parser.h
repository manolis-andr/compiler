/* A Bison parser, made by GNU Bison 3.0.2.  */

/* Bison interface for Yacc-like parsers in C

   Copyright (C) 1984, 1989-1990, 2000-2013 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

#ifndef YY_YY_PARSER_H_INCLUDED
# define YY_YY_PARSER_H_INCLUDED
/* Debug traces.  */
#ifndef YYDEBUG
# define YYDEBUG 0
#endif
#if YYDEBUG
extern int yydebug;
#endif

/* Token type.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
  enum yytokentype
  {
    T_and = 258,
    T_bool = 259,
    T_char = 260,
    T_decl = 261,
    T_def = 262,
    T_else = 263,
    T_elsif = 264,
    T_end = 265,
    T_exit = 266,
    T_false = 267,
    T_for = 268,
    T_head = 269,
    T_if = 270,
    T_int = 271,
    T_list = 272,
    T_mod = 273,
    T_new = 274,
    T_nil = 275,
    T_nilq = 276,
    T_not = 277,
    T_or = 278,
    T_ref = 279,
    T_return = 280,
    T_skip = 281,
    T_tail = 282,
    T_true = 283,
    T_le = 284,
    T_ge = 285,
    T_ne = 286,
    T_assign = 287,
    T_id = 288,
    T_int_const = 289,
    T_char_const = 290,
    T_string = 291
  };
#endif

/* Value type.  */
#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
typedef union YYSTYPE YYSTYPE;
union YYSTYPE
{
#line 319 "parser.y" /* yacc.c:1909  */

	Type type;
	const char * name;
	int val;
	struct expr_tag {
		Type		type;
		bool		lval;
		bool		cond;
		Operand		place;
		List *		TRUE;
		List *		FALSE;
	} expr;
	struct rval_tag {
		Type		type;
		bool		cond;
		Operand		place;
		List *		TRUE;
		List *		FALSE;
	} rval;
	struct atom_tag {
		Type		type;
		Operand		place;
		bool		lval;
	}atom;
	struct call_tag {
		Type		type;
		Operand		place;
	}call;
	struct stmt_tag {
		List *			NEXT;
	}stmt;

#line 124 "parser.h" /* yacc.c:1909  */
};
# define YYSTYPE_IS_TRIVIAL 1
# define YYSTYPE_IS_DECLARED 1
#endif


extern YYSTYPE yylval;

int yyparse (void);

#endif /* !YY_YY_PARSER_H_INCLUDED  */
