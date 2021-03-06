//          Copyright Brian Schott (Hackerpilot) 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module analysis.del;

import std.stdio;
import std.d.ast;
import std.d.lexer;
import analysis.base;
import analysis.helpers;

/**
 * Checks for use of the deprecated 'delete' keyword
 */
class DeleteCheck : BaseAnalyzer
{
	alias visit = BaseAnalyzer.visit;

	this(string fileName)
	{
		super(fileName);
	}

	override void visit(const DeleteExpression d)
	{
		addErrorMessage(d.line, d.column, "dscanner.deprecated.delete_keyword",
			"Avoid using the 'delete' keyword.");
		d.accept(this);
	}
}

unittest
{
	import analysis.config;
	StaticAnalysisConfig sac;
	sac.delete_check = true;
	assertAnalyzerWarnings(q{
		void testDelete()
		{
			int[int] data = [1 : 2];
			delete data[1]; // [warn]: Avoid using the 'delete' keyword.

			auto a = new Class();
			delete a; // [warn]: Avoid using the 'delete' keyword.
		}
	}c, sac);

	stderr.writeln("Unittest for DeleteCheck passed.");
}

