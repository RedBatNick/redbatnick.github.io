package headers

when ODIN_OS == .Linux {
	foreign import lib "linux/libcmark.so.0.31.2"
}
import "core:c"

@(default_calling_convention = "c")
foreign lib {
	/** Convert 'text' (assumed to be a UTF-8 encoded string with length
	* 'len') from CommonMark Markdown to HTML, returning a null-terminated,
	* UTF-8-encoded string. It is the caller's responsibility
	* to free the returned buffer.
	*/
	@(link_name = "cmark_markdown_to_html")
	markdown_to_html :: proc(text: cstring, len: c.size_t, options: i32) -> cstring ---
}

/** ## Node Structure
*/
NodeType :: enum u32 {
	/* Error status */
	NONE           = 0,

	/* Block */
	DOCUMENT       = 1,
	BLOCK_QUOTE    = 2,
	LIST           = 3,
	ITEM           = 4,
	CODE_BLOCK     = 5,
	HTML_BLOCK     = 6,
	CUSTOM_BLOCK   = 7,
	PARAGRAPH      = 8,
	HEADING        = 9,
	THEMATIC_BREAK = 10,
	FIRST_BLOCK    = 1,
	LAST_BLOCK     = 10,

	/* Inline */
	TEXT           = 11,
	SOFTBREAK      = 12,
	LINEBREAK      = 13,
	CODE           = 14,
	HTML_INLINE    = 15,
	CUSTOM_INLINE  = 16,
	EMPH           = 17,
	STRONG         = 18,
	LINK           = 19,
	IMAGE          = 20,
	FIRST_INLINE   = 11,
	LAST_INLINE    = 20,
}

ListType :: enum u32 {
	NO_LIST      = 0,
	BULLET_LIST  = 1,
	ORDERED_LIST = 2,
}

DelimType :: enum u32 {
	NO_DELIM     = 0,
	PERIOD_DELIM = 1,
	PAREN_DELIM  = 2,
}

Node :: struct {}
Parser :: struct {}
Iter :: struct {}

/** Defines the memory allocation functions to be used by CMark
* when parsing and allocating a document tree
*/
Mem :: struct {
	calloc:  proc "c" (_: c.size_t, _: c.size_t) -> rawptr,
	realloc: proc "c" (_: rawptr, _: c.size_t) -> rawptr,
	free:    proc "c" (_: rawptr),
}

@(default_calling_convention = "c")
foreign lib {
	/** Returns a pointer to the default memory allocator.
	*/
	@(link_name = "cmark_get_default_mem_allocator")
	get_default_mem_allocator :: proc() -> ^Mem ---

	/** Returns true if the node is a block node.
	*/
	@(link_name = "cmark_node_is_block")
	node_is_block :: proc(node: ^Node) -> bool ---

	/** Returns true if the node is an inline node.
	*/
	@(link_name = "cmark_node_is_inline")
	node_is_inline :: proc(node: ^Node) -> bool ---

	/** Returns true if the node is a leaf node (a node that cannot
	contain children).
	*/
	@(link_name = "cmark_node_is_leaf")
	node_is_leaf :: proc(node: ^Node) -> bool ---

	/** Creates a new node of type 'type'.  Note that the node may have
	* other required properties, which it is the caller's responsibility
	* to assign.
	*/
	@(link_name = "cmark_node_new")
	node_new :: proc(type: NodeType) -> ^Node ---

	/** Same as `cmark_node_new`, but explicitly listing the memory
	* allocator used to allocate the node.  Note:  be sure to use the same
	* allocator for every node in a tree, or bad things can happen.
	*/
	@(link_name = "cmark_node_new_with_mem")
	node_new_with_mem :: proc(type: NodeType, mem: ^Mem) -> ^Node ---

	/** Frees the memory allocated for a node and any children.
	*/
	@(link_name = "cmark_node_free")
	node_free :: proc(node: ^Node) ---

	/** Returns the next node in the sequence after 'node', or NULL if
	* there is none.
	*/
	@(link_name = "cmark_node_next")
	node_next :: proc(node: ^Node) -> ^Node ---

	/** Returns the previous node in the sequence after 'node', or NULL if
	* there is none.
	*/
	@(link_name = "cmark_node_previous")
	node_previous :: proc(node: ^Node) -> ^Node ---

	/** Returns the parent of 'node', or NULL if there is none.
	*/
	@(link_name = "cmark_node_parent")
	node_parent :: proc(node: ^Node) -> ^Node ---

	/** Returns the first child of 'node', or NULL if 'node' has no children.
	*/
	@(link_name = "cmark_node_first_child")
	node_first_child :: proc(node: ^Node) -> ^Node ---

	/** Returns the last child of 'node', or NULL if 'node' has no children.
	*/
	@(link_name = "cmark_node_last_child")
	node_last_child :: proc(node: ^Node) -> ^Node ---
}

/**
* ## Iterator
*
* An iterator will walk through a tree of nodes, starting from a root
* node, returning one node at a time, together with information about
* whether the node is being entered or exited.  The iterator will
* first descend to a child node, if there is one.  When there is no
* child, the iterator will go to the next sibling.  When there is no
* next sibling, the iterator will return to the parent (but with
* a 'cmark_event_type' of `CMARK_EVENT_EXIT`).  The iterator will
* return `CMARK_EVENT_DONE` when it reaches the root node again.
* One natural application is an HTML renderer, where an `ENTER` event
* outputs an open tag and an `EXIT` event outputs a close tag.
* An iterator might also be used to transform an AST in some systematic
* way, for example, turning all level-3 headings into regular paragraphs.
*
*     void
*     usage_example(cmark_node *root) {
*         cmark_event_type ev_type;
*         cmark_iter *iter = cmark_iter_new(root);
*
*         while ((ev_type = cmark_iter_next(iter)) != CMARK_EVENT_DONE) {
*             cmark_node *cur = cmark_iter_get_node(iter);
*             // Do something with `cur` and `ev_type`
*         }
*
*         cmark_iter_free(iter);
*     }
*
* Iterators will never return `EXIT` events for leaf nodes, which are nodes
* of type:
*
* * CMARK_NODE_HTML_BLOCK
* * CMARK_NODE_THEMATIC_BREAK
* * CMARK_NODE_CODE_BLOCK
* * CMARK_NODE_TEXT
* * CMARK_NODE_SOFTBREAK
* * CMARK_NODE_LINEBREAK
* * CMARK_NODE_CODE
* * CMARK_NODE_HTML_INLINE
*
* Nodes must only be modified after an `EXIT` event, or an `ENTER` event for
* leaf nodes.
*/
cmark_event_type :: enum u32 {
	NONE  = 0,
	DONE  = 1,
	ENTER = 2,
	EXIT  = 3,
}

@(default_calling_convention = "c")
foreign lib {
	/** Creates a new iterator starting at 'root'.  The current node and event
	* type are undefined until 'cmark_iter_next' is called for the first time.
	* The memory allocated for the iterator should be released using
	* 'cmark_iter_free' when it is no longer needed.
	*/
	@(link_name = "cmark_iter_new")
	iter_new :: proc(root: ^Node) -> ^Iter ---

	/** Frees the memory allocated for an iterator.
	*/
	@(link_name = "cmark_iter_free")
	iter_free :: proc(iter: ^Iter) ---

	/** Advances to the next node and returns the event type (`CMARK_EVENT_ENTER`,
	* `CMARK_EVENT_EXIT` or `CMARK_EVENT_DONE`).
	*/
	@(link_name = "cmark_iter_next")
	iter_next :: proc(iter: ^Iter) -> cmark_event_type ---

	/** Returns the current node.
	*/
	@(link_name = "cmark_iter_get_node")
	iter_get_node :: proc(iter: ^Iter) -> ^Node ---

	/** Returns the current event type.
	*/
	@(link_name = "cmark_iter_get_event_type")
	iter_get_event_type :: proc(iter: ^Iter) -> cmark_event_type ---

	/** Returns the root node.
	*/
	@(link_name = "cmark_iter_get_root")
	iter_get_root :: proc(iter: ^Iter) -> ^Node ---

	/** Resets the iterator so that the current node is 'current' and
	* the event type is 'event_type'.  The new current node must be a
	* descendant of the root node or the root node itself.
	*/
	@(link_name = "cmark_iter_reset")
	iter_reset :: proc(iter: ^Iter, current: ^Node, event_type: cmark_event_type) ---

	/** Returns the user data of 'node'.
	*/
	@(link_name = "cmark_node_get_user_data")
	node_get_user_data :: proc(node: ^Node) -> rawptr ---

	/** Sets arbitrary user data for 'node'.  Returns 1 on success,
	* 0 on failure.
	*/
	@(link_name = "cmark_node_set_user_data")
	node_set_user_data :: proc(node: ^Node, user_data: rawptr) -> i32 ---

	/** Returns the type of 'node', or `CMARK_NODE_NONE` on error.
	*/
	@(link_name = "cmark_node_get_type")
	node_get_type :: proc(node: ^Node) -> NodeType ---

	/** Like 'cmark_node_get_type', but returns a string representation
	of the type, or `"<unknown>"`.
	*/
	@(link_name = "cmark_node_get_type_string")
	node_get_type_string :: proc(node: ^Node) -> cstring ---

	/** Returns the string contents of 'node', or an empty
	string if none is set.  Returns NULL if called on a
	node that does not have string content.
	*/
	@(link_name = "cmark_node_get_literal")
	node_get_literal :: proc(node: ^Node) -> cstring ---

	/** Sets the string contents of 'node'.  Returns 1 on success,
	* 0 on failure.
	*/
	@(link_name = "cmark_node_set_literal")
	node_set_literal :: proc(node: ^Node, content: cstring) -> i32 ---

	/** Returns the heading level of 'node', or 0 if 'node' is not a heading.
	*/
	@(link_name = "cmark_node_get_heading_level")
	node_get_heading_level :: proc(node: ^Node) -> i32 ---
}

/* For backwards compatibility */
node_get_header_level :: node_get_heading_level
node_set_header_level :: node_set_heading_level

@(default_calling_convention = "c")
foreign lib {
	/** Sets the heading level of 'node', returning 1 on success and 0 on error.
	*/
	@(link_name = "cmark_node_set_heading_level")
	node_set_heading_level :: proc(node: ^Node, level: i32) -> i32 ---

	/** Returns the list type of 'node', or `CMARK_NO_LIST` if 'node'
	* is not a list.
	*/
	@(link_name = "cmark_node_get_list_type")
	node_get_list_type :: proc(node: ^Node) -> ListType ---

	/** Sets the list type of 'node', returning 1 on success and 0 on error.
	*/
	@(link_name = "cmark_node_set_list_type")
	node_set_list_type :: proc(node: ^Node, type: ListType) -> i32 ---

	/** Returns the list delimiter type of 'node', or `CMARK_NO_DELIM` if 'node'
	* is not a list.
	*/
	@(link_name = "cmark_node_get_list_delim")
	node_get_list_delim :: proc(node: ^Node) -> DelimType ---

	/** Sets the list delimiter type of 'node', returning 1 on success and 0
	* on error.
	*/
	@(link_name = "cmark_node_set_list_delim")
	node_set_list_delim :: proc(node: ^Node, delim: DelimType) -> i32 ---

	/** Returns starting number of 'node', if it is an ordered list, otherwise 0.
	*/
	@(link_name = "cmark_node_get_list_start")
	node_get_list_start :: proc(node: ^Node) -> i32 ---

	/** Sets starting number of 'node', if it is an ordered list. Returns 1
	* on success, 0 on failure.
	*/
	@(link_name = "cmark_node_set_list_start")
	node_set_list_start :: proc(node: ^Node, start: i32) -> i32 ---

	/** Returns 1 if 'node' is a tight list, 0 otherwise.
	*/
	@(link_name = "cmark_node_get_list_tight")
	node_get_list_tight :: proc(node: ^Node) -> i32 ---

	/** Sets the "tightness" of a list.  Returns 1 on success, 0 on failure.
	*/
	@(link_name = "cmark_node_set_list_tight")
	node_set_list_tight :: proc(node: ^Node, tight: i32) -> i32 ---

	/** Returns the info string from a fenced code block.
	*/
	@(link_name = "cmark_node_get_fence_info")
	node_get_fence_info :: proc(node: ^Node) -> cstring ---

	/** Sets the info string in a fenced code block, returning 1 on
	* success and 0 on failure.
	*/
	@(link_name = "cmark_node_set_fence_info")
	node_set_fence_info :: proc(node: ^Node, info: cstring) -> i32 ---

	/** Returns the URL of a link or image 'node', or an empty string
	if no URL is set.  Returns NULL if called on a node that is
	not a link or image.
	*/
	@(link_name = "cmark_node_get_url")
	node_get_url :: proc(node: ^Node) -> cstring ---

	/** Sets the URL of a link or image 'node'. Returns 1 on success,
	* 0 on failure.
	*/
	@(link_name = "cmark_node_set_url")
	node_set_url :: proc(node: ^Node, url: cstring) -> i32 ---

	/** Returns the title of a link or image 'node', or an empty
	string if no title is set.  Returns NULL if called on a node
	that is not a link or image.
	*/
	@(link_name = "cmark_node_get_title")
	node_get_title :: proc(node: ^Node) -> cstring ---

	/** Sets the title of a link or image 'node'. Returns 1 on success,
	* 0 on failure.
	*/
	@(link_name = "cmark_node_set_title")
	node_set_title :: proc(node: ^Node, title: cstring) -> i32 ---

	/** Returns the literal "on enter" text for a custom 'node', or
	an empty string if no on_enter is set.  Returns NULL if called
	on a non-custom node.
	*/
	@(link_name = "cmark_node_get_on_enter")
	node_get_on_enter :: proc(node: ^Node) -> cstring ---

	/** Sets the literal text to render "on enter" for a custom 'node'.
	Any children of the node will be rendered after this text.
	Returns 1 on success 0 on failure.
	*/
	@(link_name = "cmark_node_set_on_enter")
	node_set_on_enter :: proc(node: ^Node, on_enter: cstring) -> i32 ---

	/** Returns the literal "on exit" text for a custom 'node', or
	an empty string if no on_exit is set.  Returns NULL if
	called on a non-custom node.
	*/
	@(link_name = "cmark_node_get_on_exit")
	node_get_on_exit :: proc(node: ^Node) -> cstring ---

	/** Sets the literal text to render "on exit" for a custom 'node'.
	Any children of the node will be rendered before this text.
	Returns 1 on success 0 on failure.
	*/
	@(link_name = "cmark_node_set_on_exit")
	node_set_on_exit :: proc(node: ^Node, on_exit: cstring) -> i32 ---

	/** Returns the line on which 'node' begins.
	*/
	@(link_name = "cmark_node_get_start_line")
	node_get_start_line :: proc(node: ^Node) -> i32 ---

	/** Returns the column at which 'node' begins.
	*/
	@(link_name = "cmark_node_get_start_column")
	node_get_start_column :: proc(node: ^Node) -> i32 ---

	/** Returns the line on which 'node' ends.
	*/
	@(link_name = "cmark_node_get_end_line")
	node_get_end_line :: proc(node: ^Node) -> i32 ---

	/** Returns the column at which 'node' ends.
	*/
	@(link_name = "cmark_node_get_end_column")
	node_get_end_column :: proc(node: ^Node) -> i32 ---

	/** Unlinks a 'node', removing it from the tree, but not freeing its
	* memory.  (Use 'cmark_node_free' for that.)
	*/
	@(link_name = "cmark_node_unlink")
	node_unlink :: proc(node: ^Node) ---

	/** Inserts 'sibling' before 'node'.  Returns 1 on success, 0 on failure.
	*/
	@(link_name = "cmark_node_insert_before")
	node_insert_before :: proc(node: ^Node, sibling: ^Node) -> i32 ---

	/** Inserts 'sibling' after 'node'. Returns 1 on success, 0 on failure.
	*/
	@(link_name = "cmark_node_insert_after")
	node_insert_after :: proc(node: ^Node, sibling: ^Node) -> i32 ---

	/** Replaces 'oldnode' with 'newnode' and unlinks 'oldnode' (but does
	* not free its memory).
	* Returns 1 on success, 0 on failure.
	*/
	@(link_name = "cmark_node_replace")
	node_replace :: proc(oldnode: ^Node, newnode: ^Node) -> i32 ---

	/** Adds 'child' to the beginning of the children of 'node'.
	* Returns 1 on success, 0 on failure.
	*/
	@(link_name = "cmark_node_prepend_child")
	node_prepend_child :: proc(node: ^Node, child: ^Node) -> i32 ---

	/** Adds 'child' to the end of the children of 'node'.
	* Returns 1 on success, 0 on failure.
	*/
	@(link_name = "cmark_node_append_child")
	node_append_child :: proc(node: ^Node, child: ^Node) -> i32 ---

	/** Consolidates adjacent text nodes.
	*/
	@(link_name = "cmark_consolidate_text_nodes")
	consolidate_text_nodes :: proc(root: ^Node) ---

	/** Creates a new parser object.
	*/
	@(link_name = "cmark_parser_new")
	parser_new :: proc(options: i32) -> ^Parser ---

	/** Creates a new parser object with the given memory allocator
	*
	* A generalization of `cmark_parser_new`:
	* ```c
	* cmark_parser_new(options)
	* ```
	* is the same as:
	* ```c
	* cmark_parser_new_with_mem(options, cmark_get_default_mem_allocator())
	* ```
	*/
	@(link_name = "cmark_parser_new_with_mem")
	parser_new_with_mem :: proc(options: i32, mem: ^Mem) -> ^Parser ---

	/** Creates a new parser object with the given node to use as the root
	* node of the parsed AST.
	*
	* When parsing, children are always appended, not prepended; that means
	* if `root` already has children, the newly-parsed children will appear
	* after the given children.
	*
	* A generalization of `cmark_parser_new_with_mem`:
	* ```c
	* cmark_parser_new_with_mem(options, mem)
	* ```
	* is approximately the same as:
	* ```c
	* cmark_parser_new_with_mem_into_root(options, mem, cmark_node_new(CMARK_NODE_DOCUMENT))
	* ```
	*
	* This is useful for creating a single document out of multiple parsed
	* document fragments.
	*/
	@(link_name = "cmark_parser_new_with_mem_into_root")
	parser_new_with_mem_into_root :: proc(options: i32, mem: ^Mem, root: ^Node) -> ^Parser ---

	/** Frees memory allocated for a parser object.
	*/
	@(link_name = "cmark_parser_free")
	parser_free :: proc(parser: ^Parser) ---

	/** Feeds a string of length 'len' to 'parser'.
	*/
	@(link_name = "cmark_parser_feed")
	parser_feed :: proc(parser: ^Parser, buffer: cstring, len: c.size_t) ---

	/** Finish parsing and return a pointer to a tree of nodes.
	*/
	@(link_name = "cmark_parser_finish")
	parser_finish :: proc(parser: ^Parser) -> ^Node ---

	/** Parse a CommonMark document in 'buffer' of length 'len'.
	* Returns a pointer to a tree of nodes.  The memory allocated for
	* the node tree should be released using 'cmark_node_free'
	* when it is no longer needed.
	*/
	@(link_name = "cmark_parse_document")
	parse_document :: proc(buffer: cstring, len: c.size_t, options: i32) -> ^Node ---

	/** Render a 'node' tree as XML.  It is the caller's responsibility
	* to free the returned buffer.
	*/
	@(link_name = "cmark_render_xml")
	render_xml :: proc(root: ^Node, options: i32) -> cstring ---

	/** Render a 'node' tree as an HTML fragment.  It is up to the user
	* to add an appropriate header and footer. It is the caller's
	* responsibility to free the returned buffer.
	*/
	@(link_name = "cmark_render_html")
	render_html :: proc(root: ^Node, options: i32) -> cstring ---

	/** Render a 'node' tree as a groff man page, without the header.
	* It is the caller's responsibility to free the returned buffer.
	*/
	@(link_name = "cmark_render_man")
	render_man :: proc(root: ^Node, options: i32, width: i32) -> cstring ---

	/** Render a 'node' tree as a commonmark document.
	* It is the caller's responsibility to free the returned buffer.
	*/
	@(link_name = "cmark_render_commonmark")
	render_commonmark :: proc(root: ^Node, options: i32, width: i32) -> cstring ---

	/** Render a 'node' tree as a LaTeX document.
	* It is the caller's responsibility to free the returned buffer.
	*/
	@(link_name = "cmark_render_latex")
	render_latex :: proc(root: ^Node, options: i32, width: i32) -> cstring ---
}

/**
* ## Options
*/

/** Default options.
*/
OPT_DEFAULT :: 0

/**
* ### Options affecting rendering
*/

/** Include a `data-sourcepos` attribute on all block elements.
*/
OPT_SOURCEPOS :: (1 << 1)

/** Render `softbreak` elements as hard line breaks.
*/
OPT_HARDBREAKS :: (1 << 2)

/** `OPT_SAFE` is defined here for API compatibility,
but it no longer has any effect. "Safe" mode is now the default:
set `OPT_UNSAFE` to disable it.
*/
OPT_SAFE :: (1 << 3)

/** Render raw HTML and unsafe links (`javascript:`, `vbscript:`,
* `file:`, and `data:`, except for `image/png`, `image/gif`,
* `image/jpeg`, or `image/webp` mime types).  By default,
* raw HTML is replaced by a placeholder HTML comment. Unsafe
* links are replaced by empty strings.
*/
OPT_UNSAFE :: (1 << 17)

/** Render `softbreak` elements as spaces.
*/
OPT_NOBREAKS :: (1 << 4)

/**
* ### Options affecting parsing
*/

/** Legacy option (no effect).
*/
OPT_NORMALIZE :: (1 << 8)

/** Validate UTF-8 in the input before parsing, replacing illegal
* sequences with the replacement character U+FFFD.
*/
OPT_VALIDATE_UTF8 :: (1 << 9)

/** Convert straight quotes to curly, `---` to em dashes, `--` to en dashes.
*/
OPT_SMART :: (1 << 10)

@(default_calling_convention = "c")
foreign lib {
	/** The library version as integer for runtime checks. Also available as
	* macro CMARK_VERSION for compile time checks.
	*
	* * Bits 16-23 contain the major version.
	* * Bits 8-15 contain the minor version.
	* * Bits 0-7 contain the patchlevel.
	*
	* In hexadecimal format, the number 0x010203 represents version 1.2.3.
	*/
	@(link_name = "cmark_version")
	version :: proc() -> i32 ---

	/** The library version string for runtime checks. Also available as
	* macro CMARK_VERSION_STRING for compile time checks.
	*/
	@(link_name = "cmark_version_string")
	version_string :: proc() -> cstring ---
}

