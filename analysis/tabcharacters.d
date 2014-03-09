//          Copyright Brian Schott 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module analysis.tabcharacters;

import std.algorithm;
import stdx.d.lexer;
import analysis.base;

/**
 * Checks for files that contain tab characters
 */
class TabCharacterCheck : BaseAnalyzer
{
	this(string fileName)
	{
		super(fileName);
	}

	override void analyze(const(Token)[] tokens)
	{
		foreach (t; tokens)
		{
			if (t.type == tok!"whitespace"
				&& t.text !is null
				&& (cast(ubyte[]) t.text).canFind('\t'))
			{
				addErrorMessage(t.line, t.column, "File contains tab characters");
				return;
			}
		}
	}
}
