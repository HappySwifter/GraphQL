/**
 * Given a Source object, this returns a Lexer for that source.
 * A Lexer is a stateful stream generator in that every time
 * it is advanced, it returns the next token in the Source. Assuming the
 * source lexes, the final Token emitted by the lexer will be of kind
 * EOF, after which the lexer will repeatedly return the same EOF token
 * whenever called.
 */
func createLexer(source: Source, noLocation: Bool = false) -> Lexer {
    let startOfFileToken = Token(
        kind: .sof,
        start: 0,
        end: 0,
        line: 0,
        column: 0,
        value: nil
    )

    let lexer: Lexer = Lexer(
        source: source,
        noLocation: noLocation,
        lastToken: startOfFileToken,
        token: startOfFileToken,
        line: 1,
        lineStart: 0,
        advance: advanceLexer
    )

    return lexer
}

func advanceLexer(lexer: Lexer) throws -> Token {
    lexer.lastToken = lexer.token
    var token = lexer.lastToken

      if token.kind != .eof {
        repeat {
            token.next = try readToken(lexer: lexer, prev: token)
            token = token.next!
        } while token.kind == .comment

        lexer.token = token
      }

    return token
}

/**
 * The return type of createLexer.
 */
final class Lexer {
    let source: Source
    let noLocation: Bool

    /**
     * The previously focused non-ignored token.
     */
    var lastToken: Token

    /**
     * The currently focused non-ignored token.
     */
    var token: Token

    /**
     * The (1-indexed) line containing the current token.
     */
    var line: Int

    /**
     * The character offset at which the current line begins.
     */
    var lineStart: Int

    /**
     * Advances the token stream to the next non-ignored token.
     */
    let advanceFunction: (Lexer) throws -> Token

    init(source: Source, noLocation: Bool, lastToken: Token, token: Token, line: Int, lineStart: Int, advance: @escaping (Lexer) throws -> Token) {
        self.source = source
        self.noLocation = noLocation
        self.lastToken = lastToken
        self.token = token
        self.line = line
        self.lineStart = lineStart
        self.advanceFunction = advance
    }

    @discardableResult
    func advance() throws -> Token {
        return try advanceFunction(self)
    }
}

// Each kind of token.
//const SOF = '<SOF>'
//const EOF = '<EOF>'
//const BANG = '!'
//const DOLLAR = '$'
//const PAREN_L = '('
//const PAREN_R = ')'
//const SPREAD = '...'
//const COLON = ':'
//const EQUALS = '='
//const AT = '@'
//const BRACKET_L = '['
//const BRACKET_R = ']'
//const BRACE_L = '{'
//const PIPE = '|'
//const BRACE_R = '}'
//const NAME = 'Name'
//const INT = 'Int'
//const FLOAT = 'Float'
//const STRING = 'String'
//const COMMENT = 'Comment'

/**
 * An exported enum describing the different kinds of tokens that the
 * lexer emits.
 */
//export const TokenKind = {
//  SOF,
//  EOF,
//  BANG,
//  DOLLAR,
//  PAREN_L,
//  PAREN_R,
//  SPREAD,
//  COLON,
//  EQUALS,
//  AT,
//  BRACKET_L,
//  BRACKET_R,
//  BRACE_L,
//  PIPE,
//  BRACE_R,
//  NAME,
//  INT,
//  FLOAT,
//  STRING,
//  COMMENT
//}

/**
 * A helper function to describe a token as a string for debugging
 */
func getTokenDesc(token: Token) -> String {
    if let value = token.value {
        return "\(token.kind) \"\(value)\""
    }

    return "\(token.kind)"
}

//const slice = String.prototype.slice

extension String {
    func charCode(at position: Int) -> UInt8? {
        // TODO: calculate out of bounds and return nil
        return utf8[utf8.index(utf8.startIndex, offsetBy: position)]
    }

    func slice(start: Int, end: Int) -> String {
        let startIndex = utf8.index(utf8.startIndex, offsetBy: start)
        let endIndex = utf8.index(utf8.startIndex, offsetBy: end)
        var slice: [UInt8] = utf8[startIndex..<endIndex] + [0]
        return String(cString: &slice)
    }
}

/**
 * Helper function for constructing the Token object.
 */
//function Tok(
//  kind,
//  start: number,
//  end: number,
//  line: number,
//  column: number,
//  prev: Token | null,
//  value?: string
//) {
//  this.kind = kind
//  this.start = start
//  this.end = end
//  this.line = line
//  this.column = column
//  this.value = value
//  this.prev = prev
//  this.next = null
//}

// Print a simplified form when appearing in JSON/util.inspect.
//Tok.prototype.toJSON = Tok.prototype.inspect = function toJSON() {
//  return {
//    kind: this.kind,
//    value: this.value,
//    line: this.line,
//    column: this.column
//  }
//}

//function printCharCode(code) {
//  return (
//    // NaN/undefined represents access beyond the end of the file.
//    isNaN(code) ? EOF :
//    // Trust JSON for ASCII.
//    code < 0x007F ? JSON.stringify(String.fromCharCode(code)) :
//    // Otherwise print the escaped form.
//    `"\\u${('00' + code.toString(16).toUpperCase()).slice(-4)}"`
//  )
//}

enum SyntaxError : Error {
    case unexpectedCharacter
    case invalidCharacter
    case unexpectedEndOfFile
    case invalidCharacterEscapeSequence
    case unterminatedString
    case unexpectedToken
}

/**
 * Gets the next token from the source starting at the given position.
 *
 * This skips over whitespace and comments until it finds the next lexable
 * token, then lexes punctuators immediately or calls the appropriate helper
 * function for more complicated tokens.
 */
func readToken(lexer: Lexer, prev: Token) throws -> Token {
    let source = lexer.source
    let body = source.body
    let bodyLength = body.utf8.count

    let position = positionAfterWhitespace(body: body, startPosition: prev.end, lexer: lexer)
    let line = lexer.line
    let col = 1 + position - lexer.lineStart

    if position >= bodyLength {
        return Token(
            kind: .eof,
            start: bodyLength,
            end: bodyLength,
            line: line,
            column: col,
            prev: prev
        )
    }

    guard let code = body.charCode(at: position) else {
        throw SyntaxError.unexpectedEndOfFile
        //  throw syntaxError(
        //    source,
        //    position,
        //    `Unexpected character ${printCharCode(code)}.`
        //  )
    }

    // SourceCharacter
    if code < 0x0020 && code != 0x0009 && code != 0x000A && code != 0x000D {
        throw SyntaxError.invalidCharacter
//        throw syntaxError(
//        source,
//        position,
//        `Invalid character ${printCharCode(code)}.`
//        )
    }

    switch code {
    // !
    case 33:
        return Token(
            kind: .bang,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // #
    case 35:
        return readComment(
            source: source,
            start: position,
            line: line,
            col: col,
            prev: prev
        )
    // $
    case 36:
        return Token(
            kind: .dollar,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // (
    case 40:
        return Token(
            kind: .openingParenthesis,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // )
    case 41:
        return Token(
            kind: .closingParenthesis,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // .
    case 46:
      if body.charCode(at: position + 1) == 46 &&
          body.charCode(at: position + 2) == 46 {
        return Token(
            kind: .spread,
            start: position,
            end: position + 3,
            line: line,
            column: col,
            prev: prev
        )
      }
    // :
    case 58:
        return Token(
            kind: .colon,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // =
    case 61:
        return Token(
            kind: .equals,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // @
    case 64:
        return Token(
            kind: .at,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // [
    case 91:
        return Token(
            kind: .openingBracket,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // ]
    case 93:
        return Token(
            kind: .closingBracket,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // {
    case 123:
        return Token(
            kind: .openingBrace,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // |
    case 124:
        return Token(
            kind: .pipe,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // }
    case 125:
        return Token(
            kind: .closingBrace,
            start: position,
            end: position + 1,
            line: line,
            column: col,
            prev: prev
        )
    // A-Z _ a-z
    case 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 95, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122:
        return readName(
            source: source,
            position: position,
            line: line,
            col: col,
            prev: prev)
    // - 0-9
    case 45, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57:
        return try readNumber(
            source: source,
            start: position,
            firstCode: code,
            line: line,
            col: col,
            prev: prev
        )
    // "
    case 34:
        return try readString(
            source: source,
            start: position,
            line: line,
            col: col,
            prev: prev
        )
    default:
        throw SyntaxError.unexpectedCharacter
        //  throw syntaxError(
        //    source,
        //    position,
        //    `Unexpected character ${printCharCode(code)}.`
        //  )
  }

    throw SyntaxError.unexpectedCharacter
}

/**
 * Reads from body starting at startPosition until it finds a non-whitespace
 * or commented character, then returns the position of that character for
 * lexing.
 */
func positionAfterWhitespace(body: String, startPosition: Int, lexer: Lexer) -> Int {
    let bodyLength = body.utf8.count
    var position = startPosition

    while position < bodyLength {
        let code = body.charCode(at: position)
        // tab | space | comma | BOM
        if code == 9 || code == 32 || code == 44 { // || code == 0xFEFF {
            position += 1
        } else if code == 10 { // new line
            position += 1
            lexer.line += 1
            lexer.lineStart = position
        } else if code == 13 { // carriage return
            if body.charCode(at: position + 1) == 10 {
                position += 2
            } else {
                position += 1
            }
            lexer.line += 1
            lexer.lineStart = position
        } else {
            break
        }
    }

    return position
}

/**
 * Reads a comment token from the source file.
 *
 * #[\u0009\u0020-\uFFFF]*
 */
func readComment(source: Source, start: Int, line: Int, col: Int, prev: Token) -> Token {
    let body = source.body
    var code: UInt8?
    var position = start

    while true {
        position += 1
        code = body.charCode(at: position)

        // SourceCharacter but not LineTerminator
        if let code = code, (code > 0x001F || code == 0x0009) {
            continue
        } else {
            break
        }
    }

    return Token(
        kind: .comment,
        start: start,
        end: position,
        line: line,
        column: col,
        value: body.slice(start: start + 1, end: position),
        prev: prev
    )
}

/**
 * Reads a number token from the source file, either a float
 * or an int depending on whether a decimal point appears.
 *
 * Int:   -?(0|[1-9][0-9]*)
 * Float: -?(0|[1-9][0-9]*)(\.[0-9]+)?((E|e)(+|-)?[0-9]+)?
 */
func readNumber(source: Source, start: Int, firstCode: UInt8, line: Int, col: Int, prev: Token) throws -> Token {
  let body = source.body
  var code = firstCode
    var position = start
  var isFloat = false

  if code == 45 { // -
    position += 1
    // TODO: Check out of bounds
    code = body.charCode(at: position)!
  }

  if code == 48 { // 0
    position += 1
    // TODO: Check out of bounds
    code = body.charCode(at: position)!
    if code >= 48 && code <= 57 {
        throw SyntaxError.unexpectedCharacter
//      throw syntaxError(
//        source,
//        position,
//        `Invalid number, unexpected digit after 0: ${printCharCode(code)}.`
//      )
    }
  } else {
    position = try readDigits(source: source, start: position, firstCode: code)
    // TODO: Check out of bounds
    code = body.charCode(at: position)!
  }

  if (code == 46) { // .
    isFloat = true
    position += 1
    // TODO: Check out of bounds
    code = body.charCode(at: position)!
    position = try readDigits(source: source, start: position, firstCode: code)
    // TODO: Check out of bounds
    code = body.charCode(at: position)!
  }

  if code == 69 || code == 101 { // E e
    isFloat = true
    position += 1
    // TODO: Check out of bounds
    code = body.charCode(at: position)!
    if code == 43 || code == 45 { // + -
        position += 1
        // TODO: Check out of bounds
      code = body.charCode(at: position)!
    }

    position = try readDigits(source: source, start: position, firstCode: code)
  }

  return Token(
    kind: isFloat ? .float : .int,
    start: start,
    end: position,
    line: line,
    column: col,
    value: body.slice(start: start, end: position),
    prev: prev
  )
}

/**
 * Returns the new position in the source after reading digits.
 */
func readDigits(source: Source, start: Int, firstCode: UInt8) throws -> Int {
  let body = source.body
  var position = start

  if firstCode >= 48 && firstCode <= 57 { // 0 - 9
    while true {
        position += 1
        if let code = body.charCode(at: position), code >= 48 && code <= 57 { // 0 - 9
            continue
        } else {
            break
        }
    }

    return position
  }

    throw SyntaxError.unexpectedCharacter
//  throw syntaxError(
//    source,
//    position,
//    `Invalid number, expected digit but got: ${printCharCode(code)}.`
//  )
}

/**
 * Reads a string token from the source file.
 *
 * "([^"\\\u000A\u000D]|(\\(u[0-9a-fA-F]{4}|["\\/bfnrt])))*"
 */
func readString(source: Source, start: Int, line: Int, col: Int, prev: Token) throws -> Token {
  let body = source.body
    let bodyLength = body.utf8.count
  var position = start + 1
  var chunkStart = position
    var code: UInt8? = 0
  var value = ""

  while position < bodyLength,
        let c = body.charCode(at: position),
        // not LineTerminator
        (c != 0x000A && c != 0x000D &&
        // not Quote (")
        c != 34) {

            code = c
    // SourceCharacter
    if (c < 0x0020 && c != 0x0009) {
        throw SyntaxError.invalidCharacter
//      throw syntaxError(
//        source,
//        position,
//        `Invalid character within String: ${printCharCode(code)}.`
//      )
    }

    position += 1

    if code == 92 { // \
      value += body.slice(start: chunkStart, end: position - 1)
        guard let c = body.charCode(at: position) else {
            throw SyntaxError.unexpectedEndOfFile
        }

        code = c

      switch c {
        case 34: value += "\""
        case 47: value += "/"
        case 92: value += "\\"
        // TODO: Check these escape values
//        case 98: value += "\b"
//        case 102: value += "\f"
        case 110: value += "\n"
        case 114: value += "\r"
        case 116: value += "\t"
        case 117: // u
            // TODO: check out of bounds
          let charCode = uniCharCode(
            a: body.charCode(at: position + 1)!,
            b: body.charCode(at: position + 2)!,
            c: body.charCode(at: position + 3)!,
            d: body.charCode(at: position + 4)!
          )

          if charCode < 0 {
            throw SyntaxError.invalidCharacterEscapeSequence
//            throw syntaxError(
//              source,
//              position,
//              'Invalid character escape sequence: ' +
//              `\\u${body.slice(position + 1, position + 5)}.`
//            )
          }

          value += String(Character(UnicodeScalar(charCode)!))
          position += 4
        default:
            throw SyntaxError.invalidCharacterEscapeSequence
//          throw syntaxError(
//            source,
//            position,
//            `Invalid character escape sequence: \\${String.fromCharCode(code)}.`
//          )
      }
      position += 1
      chunkStart = position
    }
  }

  if code != 34 { // quote (")
    throw SyntaxError.unterminatedString
//    throw syntaxError(source, position, 'Unterminated string.')
  }

    value += body.slice(start: chunkStart, end: position)

  return Token(
        kind: .string,
        start: start,
        end: position + 1,
        line: line,
        column: col,
        value: value,
        prev: prev
    )
}

/**
 * Converts four hexidecimal chars to the integer that the
 * string represents. For example, uniCharCode('0','0','0','f')
 * will return 15, and uniCharCode('0','0','f','f') returns 255.
 *
 * Returns a negative number on error, if a char was invalid.
 *
 * This is implemented by noting that char2hex() returns -1 on error,
 * which means the result of ORing the char2hex() will also be negative.
 */
func uniCharCode(a: UInt8, b: UInt8, c: UInt8, d: UInt8) -> UInt32 {
  return UInt32(char2hex(a) << 12 | char2hex(b) << 8 | char2hex(c) << 4 | char2hex(d))
}

/**
 * Converts a hex character to its integer value.
 * '0' becomes 0, '9' becomes 9
 * 'A' becomes 10, 'F' becomes 15
 * 'a' becomes 10, 'f' becomes 15
 *
 * Returns -1 on error.
 */
func char2hex(_ a: UInt8) -> Int {
    let a = Int(a)
    return a >= 48 && a <= 57 ? a - 48 : // 0-9
           a >= 65 && a <= 70 ? a - 55 : // A-F
           a >= 97 && a <= 102 ? a - 87 : // a-f
           -1
}

/**
 * Reads an alphanumeric + underscore name from the source.
 *
 * [_A-Za-z][_0-9A-Za-z]*
 */
func readName(source: Source, position: Int, line: Int, col: Int, prev: Token) -> Token {
    let body = source.body
    let bodyLength = body.utf8.count
    var end = position + 1

    while end != bodyLength,
          let code = body.charCode(at: end),
          (code == 95 || // _
           code >= 48 && code <= 57 || // 0-9
           code >= 65 && code <= 90 || // A-Z
           code >= 97 && code <= 122) { // a-z
        end += 1
    }

    return Token(
        kind: .name,
        start: position,
        end: end,
        line: line,
        column: col,
        value: body.slice(start: position, end: end),
        prev: prev
    )
}
