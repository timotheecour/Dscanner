module analysis.base;

import std.container;
import std.string;
import stdx.d.ast;
import stdx.d.lexer;
import std.array;

struct Message
{
	string fileName;
	size_t line;
	size_t column;
	string message;
	bool isError = false;
}

alias MessageSet = RedBlackTree!(Message, "a.line < b.line", true);

abstract class BaseAnalyzer : ASTVisitor
{
public:
	this(string fileName)
	{
		this.fileName = fileName;
		_messages = new MessageSet;
	}

	void analyze(const(Token)[] tokens) {}

	Message[] messages()
	{
		return _messages[].array;
	}

protected:

	bool inAggregate = false;

	template visitTemplate(T)
	{
		override void visit(const T structDec)
		{
			inAggregate = true;
			structDec.accept(this);
			inAggregate = false;
		}
	}

	void addErrorMessage(size_t line, size_t column, string message)
	{
		_messages.insert(Message(fileName, line, column, message));
	}

	/**
	 * The file name
	 */
	string fileName;

	MessageSet _messages;
}
