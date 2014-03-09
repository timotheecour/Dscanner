//          Copyright Brian Schott 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module analysis.linelength;

import stdx.d.lexer;
import analysis.base;

/**
 * Checks for lines that exceed the line length limit
 */
class LineLengthCheck : BaseAnalyzer
{
	this(string fileName)
	{
		super(fileName);
	}

	override void analyze(const(Token)[] tokens)
	{
		import std.string;
		foreach (t; tokens)
		{
			if (isTooFarRight(t) && t.line != previousLine)
			{
				previousLine = t.line;
				addErrorMessage(t.line, t.column,
					"Line length exceeds %d characters".format(maxLength));
			}
		}
	}

private:

	size_t previousLine = size_t.max;

	static bool isTooFarRight(const Token t)
	{
		if (t.column > maxLength)
			return true;
		if (isStringLiteral(t.type))
			return false;
		if (t.text is null && str(t.type).length + t.column > maxLength)
			return true;
		if (t.text.length + t.column > maxLength)
			return true;
		return false;
	}

	enum maxLength = 120;
}
