//          Copyright Brian Schott (Hackerpilot) 2012.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module ctags;

import std.d.parser;
import std.d.lexer;
import std.d.ast;
import std.algorithm;
import std.range;
import std.stdio;
import std.array;
import std.conv;
import std.typecons;

/**
 * Prints CTAGS information to the given file.
 * Includes metadata according to exuberant format used by Vim.
 * Params:
 *     output = the file that Exuberant TAGS info is written to
 *     fileNames = tags will be generated from these files
 */
void printCtags(File output, string[] fileNames)
{
	string[] tags;
	LexerConfig config;
	StringCache cache = StringCache(StringCache.defaultBucketCount);
	foreach (i, fileName; fileNames)
	{
		File f = File(fileName);
		if (f.size == 0)
			continue;
		auto bytes = uninitializedArray!(ubyte[])(to!size_t(f.size));
		writeln(i," ",fileName);
		if(!bytes.length)
			continue;//TEMP
		f.rawRead(bytes);
		auto tokens = getTokensForParser(bytes, config, &cache);
		//Module m = parseModule(tokens.array, fileName, null, &doNothing);
		Module m;
		try{
		        m = parseModule(tokens.array(), fileName, null, &handleError);
		}
		catch(Throwable e){
		        continue;
		}

		auto printer = new CTagsPrinter;
		printer.fileName = fileName;
		printer.visit(m);
		tags ~= printer.tagLines;
	}
	output.write(
		"!_TAG_FILE_FORMAT\t2\n" ~ "!_TAG_FILE_SORTED\t1\n" ~ "!_TAG_FILE_AUTHOR\tBrian Schott\n" ~ "!_TAG_PROGRAM_URL\thttps://github.com/Hackerpilot/Dscanner/\n");
	tags.sort().copy(output.lockingTextWriter);
}

private:

/// States determining how an access modifier affects tags when traversing the
/// AST.
/// The assumption is that there are fewer AST nodes and patterns that affects
/// the whole scope.
/// Therefor the default was chosen to be Reset.
enum AccessState
{
	Reset, /// when ascending the AST reset back to the previous access.
	Keep /// when ascending the AST keep the new access.
}

alias ContextType = Tuple!(string, "c", string, "access");

void doNothing(string, size_t, size_t, string, bool)
{
}

void handleError(string file , size_t line, size_t column, string msg, bool is_error) {
       writeln(file,":",line,":",column," ",msg);//TODO:LINE_
       import std.exception;
       enforce(0,"parsing error");
}

string paramsToString(Dec)(const Dec dec)
{
	import std.d.formatter : Formatter;

	auto app = appender!string();
	auto formatter = new Formatter!(typeof(app))(app);

	static if (is(Dec == FunctionDeclaration) || is(Dec == Constructor))
	{
		formatter.format(dec.parameters);
	}
	else static if (is(Dec == TemplateDeclaration))
	{
		formatter.format(dec.templateParameters);
	}

	return app.data;
}

final class CTagsPrinter
	: ASTVisitor
{
	override void visit(const ClassDeclaration dec)
	{
		tagLines ~= "%s\t%s\t%d;\"\tc\tline:%d%s%s\n".format(dec.name.text,
			fileName, dec.name.line, dec.name.line, context.c, context.access);
		auto c = context;
		context = ContextType("\tclass:" ~ dec.name.text, "\taccess:public");
		dec.accept(this);
		context = c;
	}

	override void visit(const StructDeclaration dec)
	{
		if (dec.name == tok!"")
		{
			dec.accept(this);
			return;
		}
		tagLines ~= "%s\t%s\t%d;\"\ts\tline:%d%s%s\n".format(dec.name.text,
			fileName, dec.name.line, dec.name.line, context.c, context.access);
		auto c = context;
		context = ContextType("\tstruct:" ~ dec.name.text, "\taccess:public");
		dec.accept(this);
		context = c;
	}

	override void visit(const InterfaceDeclaration dec)
	{
		tagLines ~= "%s\t%s\t%d;\"\ti\tline:%d%s%s\n".format(dec.name.text,
			fileName, dec.name.line, dec.name.line, context.c, context.access);
		auto c = context;
		context = ContextType("\tclass:" ~ dec.name.text, context.access);
		dec.accept(this);
		context = c;
	}

	override void visit(const TemplateDeclaration dec)
	{
		auto params = paramsToString(dec);

		tagLines ~= "%s\t%s\t%d;\"\tT\tline:%d%s%s\tsignature:%s\n".format(
			dec.name.text, fileName, dec.name.line, dec.name.line, context.c,
			context.access, params);
		auto c = context;
		context = ContextType("\ttemplate:" ~ dec.name.text, context.access);
		dec.accept(this);
		context = c;
	}

	override void visit(const FunctionDeclaration dec)
	{
		auto params = paramsToString(dec);

		tagLines ~= "%s\t%s\t%d;\"\tf\tline:%d%s%s\tsignature:%s\n".format(
			dec.name.text, fileName, dec.name.line, dec.name.line, context.c,
			context.access, params);
	}

	override void visit(const Constructor dec)
	{
		auto params = paramsToString(dec);

		tagLines ~= "this\t%s\t%d;\"\tf\tline:%d%s\tsignature:%s%s\n".format(fileName,
			dec.line, dec.line, context.c, params, context.access);
	}

	override void visit(const Destructor dec)
	{
		tagLines ~= "~this\t%s\t%d;\"\tf\tline:%d%s\n".format(fileName,
			dec.line, dec.line, context.c);
	}

	override void visit(const EnumDeclaration dec)
	{
		tagLines ~= "%s\t%s\t%d;\"\tg\tline:%d%s%s\n".format(dec.name.text,
			fileName, dec.name.line, dec.name.line, context.c, context.access);
		auto c = context;
		context = ContextType("\tenum:" ~ dec.name.text, context.access);
		dec.accept(this);
		context = c;
	}

	override void visit(const UnionDeclaration dec)
	{
		if (dec.name == tok!"")
		{
			dec.accept(this);
			return;
		}
		tagLines ~= "%s\t%s\t%d;\"\tu\tline:%d%s\n".format(dec.name.text,
			fileName, dec.name.line, dec.name.line, context.c);
		auto c = context;
		context = ContextType("\tunion:" ~ dec.name.text, context.access);
		dec.accept(this);
		context = c;
	}

	override void visit(const AnonymousEnumMember mem)
	{
		tagLines ~= "%s\t%s\t%d;\"\te\tline:%d%s\n".format(mem.name.text,
			fileName, mem.name.line, mem.name.line, context.c);
	}

	override void visit(const EnumMember mem)
	{
		tagLines ~= "%s\t%s\t%d;\"\te\tline:%d%s\n".format(mem.name.text,
			fileName, mem.name.line, mem.name.line, context.c);
	}

	override void visit(const VariableDeclaration dec)
	{
		foreach (d; dec.declarators)
		{
			tagLines ~= "%s\t%s\t%d;\"\tv\tline:%d%s%s\n".format(d.name.text,
				fileName, d.name.line, d.name.line, context.c, context.access);
		}
		dec.accept(this);
	}

	override void visit(const AutoDeclaration dec)
	{
		foreach (i; dec.identifiers)
		{
			tagLines ~= "%s\t%s\t%d;\"\tv\tline:%d%s%s\n".format(i.text,
				fileName, i.line, i.line, context.c, context.access);
		}
		dec.accept(this);
	}

	override void visit(const Invariant dec)
	{
		tagLines ~= "invariant\t%s\t%d;\"\tv\tline:%d%s%s\n".format(fileName,
			dec.line, dec.line, context.c, context.access);
	}

	override void visit(const ModuleDeclaration dec)
	{
		context = ContextType("", "\taccess:public");
		dec.accept(this);
	}

	override void visit(const Attribute attribute)
	{
		if (attribute.attribute != tok!"")
		{
			switch (attribute.attribute.type)
			{
			case tok!"export":
				context.access = "\taccess:public";
				break;
			case tok!"public":
				context.access = "\taccess:public";
				break;
			case tok!"package":
				context.access = "\taccess:protected";
				break;
			case tok!"protected":
				context.access = "\taccess:protected";
				break;
			case tok!"private":
				context.access = "\taccess:private";
				break;
			default:
			}
		}

		attribute.accept(this);
	}

	override void visit(const AttributeDeclaration dec)
	{
		accessSt = AccessState.Keep;
		dec.accept(this);
	}

	override void visit(const Declaration dec)
	{
		auto c = context;
		dec.accept(this);

		final switch (accessSt) with (AccessState)
		{
		case Reset:
			context = c;
			break;
		case Keep:
			break;
		}
		accessSt = AccessState.Reset;
	}

	override void visit(const Unittest dec)
	{
		// skipping symbols inside a unit test to not clutter the ctags file
		// with "temporary" symbols.
		// TODO when phobos have a unittest library investigate how that could
		// be used to describe the tests.
		// Maybe with UDA's to give the unittest a "name".
	}

	override void visit(const AliasDeclaration dec)
	{
		// Old style alias
		if (dec.identifierList)
		{
			foreach (i; dec.identifierList.identifiers)
			{
				tagLines ~= "%s\t%s\t%d;\"\ta\tline:%d%s%s\n".format(i.text,
					fileName, i.line, i.line, context.c, context.access);
			}
		}
		dec.accept(this);
	}

	override void visit(const AliasInitializer dec)
	{
		tagLines ~= "%s\t%s\t%d;\"\ta\tline:%d%s%s\n".format(dec.name.text,
			fileName, dec.name.line, dec.name.line, context.c, context.access);

		dec.accept(this);
	}

	override void visit(const AliasThisDeclaration dec)
	{
		auto name = dec.identifier;
		tagLines ~= "%s\t%s\t%d;\"\ta\tline:%d%s%s\n".format(name.text,
			fileName, name.line, name.line, context.c, context.access);

		dec.accept(this);
	}

	alias visit = ASTVisitor.visit;
	string fileName;
	string[] tagLines;
	ContextType context;
	AccessState accessSt;
}
