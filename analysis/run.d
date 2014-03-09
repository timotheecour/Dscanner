//          Copyright Brian Schott 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)


module analysis.run;

import std.stdio;
import std.array;
import std.conv;
import std.algorithm;
import std.range;
import std.array;

import stdx.d.lexer;
import stdx.d.parser;
import stdx.d.ast;

import analysis.base;
import analysis.style;
import analysis.enumarrayliteral;
import analysis.pokemon;
import analysis.del;
import analysis.fish;
import analysis.numbers;
import analysis.objectconst;
import analysis.range;
import analysis.output;

void syntaxCheck(File output, string[] fileNames, shared(StringCache)* cache)
{
	writeMessages(output, analyze(fileNames, cache, false));
}

void styleCheck(File output, string[] fileNames, shared(StringCache)* cache)
{
	writeMessages(output, analyze(fileNames, cache, true));
}

void writeMessages(File output, MessageSet[string] messages)
{
	foreach (k, v; messages)
	{
		foreach (message; v[])
		{
			output.writefln("%s(%d:%d)[%s]: %s", message.fileName, message.line,
				message.column, message.isError ? "error" : "warn ",
				message.message);
		}
	}
}

void writeReport(string[] fileNames, shared(StringCache)* cache)
{
	File reportFile = File("dscanner-analysis.html", "w");
	MessageSet[string] messages = analyze(fileNames, cache, true);
	writeHtmlReport(reportFile, messages, cache);
}

MessageSet[string] analyze(string[] fileNames, shared(StringCache)* cache,
	bool staticAnalyze)
{
	import std.parallelism;
	MessageSet[string] rVal;
	foreach (fileName; fileNames)
	{
		MessageSet set = new MessageSet;

		void messageFunction(string fileName, size_t line, size_t column,
			string message, bool isError)
		{
			set.insert(Message(fileName, line, column, message, isError));
		}

		File f = File(fileName);
		auto bytes = uninitializedArray!(ubyte[])(to!size_t(f.size));
		f.rawRead(bytes);
		auto lexer = byToken(bytes);
		auto app = appender!(typeof(lexer.front)[])();
		while (!lexer.empty)
		{
			app.put(lexer.front);
			lexer.popFront();
		}

		foreach (message; lexer.messages)
		{
			messageFunction(fileName, message.line, message.column, message.message,
				message.isError);
		}

		ParseAllocator p = new ParseAllocator;
		Module m = parseModule(app.data, fileName, p, &messageFunction);

		BaseAnalyzer[] checks;
		checks ~= new StyleChecker(fileName);
		checks ~= new EnumArrayLiteralCheck(fileName);
		checks ~= new PokemonExceptionCheck(fileName);
		checks ~= new DeleteCheck(fileName);
		checks ~= new FloatOperatorCheck(fileName);
		checks ~= new NumberStyleCheck(fileName);
		checks ~= new ObjectConstCheck(fileName);
		checks ~= new BackwardsRangeCheck(fileName);

		foreach (check; checks)
		{
			check.visit(m);
		}

		foreach(check; checks)
			foreach (message; check.messages)
				set.insert(message);

		rVal[fileName] = set;
		p.deallocateAll();
	}
	return rVal;
}

