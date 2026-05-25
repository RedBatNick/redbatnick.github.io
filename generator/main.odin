package main

import cmark "vendor:commonmark"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import "core:strconv"
import "core:encoding/entity"
import "core:net"

print_help_message :: proc() {
	fmt.println("--- Static site generator ---", flush = false)
	fmt.println("Usage: <program> <src_dir> <dest_dir>")
}

main :: proc() {
	switch len(os.args) {
	case 0, 1:
		print_help_message()
	case 2:
		fmt.println("Error: Too few arguments")
		print_help_message()
	case 3:
		src_dir := os.args[1]
		dest_dir := os.args[2]
		result := program(src_dir, dest_dir)
		if result.error != nil {
			fmt.println("Error:", result.error, result.msg)
		} else {
			fmt.println("Wrote generated static site in", dest_dir)
		}
	case:
		fmt.println("Error: Too many arguments")
	}
}

StaticWebsiteGeneratorError :: enum {
	SourceDirDoesntExist,
	DestDirDoesntExist,
	HighlightJsLanguageNotExist,
}

ProgramError :: union {
	os.Error,
	mem.Allocator_Error,
	StaticWebsiteGeneratorError,
}

Result :: struct {
	error: ProgramError,
	msg: string,
}

program :: proc(src_dir, dest_dir: string) -> Result {
	if !os.is_dir(src_dir) {
		return {.SourceDirDoesntExist, src_dir}
	}
	if !os.is_dir(dest_dir) {
		return {.DestDirDoesntExist, dest_dir}
	}

	if err := delete_recursive(dest_dir); err != nil {
		return {err, strings.concatenate({"Failed to delete something in ", dest_dir})}
	}

	abs_src_dir, _ := os.get_absolute_path(src_dir, context.allocator)
	walker := os.walker_create(src_dir)
	html := strings.builder_make()
	for info, ok := os.walker_walk(&walker); ok; info, ok  = os.walker_walk(&walker) {
		if info.name[0] == '.' {
			if info.type == .Directory {
				walker.skip_dir = true
			}
			continue
		}

		abs_path := info.fullpath
		if !os.is_absolute_path(abs_path) {
			abs_path, _ = os.get_absolute_path(abs_path, context.allocator)
		}

		if info.type == .Directory {
			dest, _ := os.join_path({dest_dir, abs_path[len(abs_src_dir):]}, context.allocator)
			os.make_directory(dest)
			continue
		}
		name, ext := os.split_filename(info.name)
		if ext != "md" {
			dest, _ := os.join_path({dest_dir, abs_path[len(abs_src_dir):]}, context.allocator)
			os.copy_file(dest, info.fullpath)
			continue
		}

		article, _ := os.read_entire_file(info.fullpath, context.allocator)
		article_escaped, _ := entity.escape_html(string(article))

		defer strings.builder_reset(&html)

		fmt.sbprint(&html, HTML_HEADER)
		article_result := handle_article(&html, string(article_escaped))
		for language in article_result.languages {
			website_path := strings.concatenate({HIGHLIGHTJS_DIR + "languages/", language, ".min.js"})
			os_path, _ := os.join_path({dest_dir, website_path}, context.allocator)
			if !os.exists(os_path) {
				fmt.println(os_path)
				return {.HighlightJsLanguageNotExist, strings.concatenate({os_path})}
			}
			fmt.sbprint(&html, "<script src=\"", website_path, "\"></script>", sep = "")
		}
		fmt.sbprint(&html, "<script>hljs.highlightAll()</script>", sep = "")
		fmt.sbprint(&html, HTML_FOOTER)

		html_string := strings.to_string(html)
		path, _ := os.split_filename(abs_path[len(abs_src_dir):])
		path, _ = os.join_path({dest_dir, path}, context.allocator)
		path, _ = os.join_filename(path, "html", context.allocator)
		if err := os.write_entire_file(path, html_string); err != nil {
			return {err, strings.concatenate({"Failed to write file at ", path})}
		}
	}
	return {nil, ""}
}

@(rodata)
delete_recursive_ignore := []string {
	"highlightjs",
	"style.css",
	"graphics.js",
}

delete_recursive :: proc(dir: string) -> os.Error {
	walker := os.walker_create(dir)
	for info, ok := os.walker_walk(&walker); ok; info, ok = os.walker_walk(&walker) {
		ignore_file := false
		for ignore in delete_recursive_ignore {
			if info.name == ignore {
				ignore_file = true
				break
			}
		}

		#partial switch info.type {
		case .Directory:
			walker.skip_dir = true
			if !ignore_file {
				os.remove_all(info.fullpath) or_return
			}
		case:
			if !ignore_file {
				os.remove(info.fullpath) or_return
			}
		}
	}
	return nil
}

HIGHLIGHTJS_DIR :: "/highlightjs/"
HTML_HEADER ::
"<!doctype html>\n" +
"<head>\n" +
"   <title>Synthasmablogia</title>\n" +
"   <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />\n" +
"   <link href=\"/style.css\" rel=\"stylesheet\" />\n" +
"	<link href=\"" + HIGHLIGHTJS_DIR + "styles/gml.min.css\" rel=\"stylesheet\" />\n" +
"</head>\n" +
"<body>\n" +
"	<canvas id=\"background\"></canvas>\n" +
"	<script src=\"/graphics.js\"></script>\n" +
"	<script src=\"" + HIGHLIGHTJS_DIR + "highlight.min.js\"></script>\n" +
"	<div class=\"article-content\">"

HTML_FOOTER ::
"	</div>\n" +
"</body>\n"

HandleArticleResult :: struct {
	languages: map[string]bool
}

handle_article :: proc(b: ^strings.Builder, article: string) -> HandleArticleResult {
	root := cmark.parse_document(raw_data(article), len(article), {})
	iter := cmark.iter_new(root)
	tags := make([dynamic]string)
	result := HandleArticleResult{languages = make(map[string]bool)}
	node_index := -1

	for ev := cmark.iter_next(iter); ev != .Done; ev = cmark.iter_next(iter) {
		node_index += 1
		node := cmark.iter_get_node(iter)
		node_type := cmark.node_get_type(node)
		switch ev {
		case .None:
			fmt.println("Info: Encountered", ev, "event")
			continue
		case .Done:
			break
		case .Enter:
			#partial switch node_type {
			case .None:
				fmt.println("Info: Encountered", node_type, "node")
			case .Document:
			case .Image:
				path := strings.clone_from_cstring(cmark.node_get_url(node))
				_, ext := os.split_filename(path)
				switch ext {
				case "mp4":
					fmt.sbprint(b, "<video controls><source src=\"", path, "\" type=\"video/mp4\"></source></video>", sep = "")
				case:
					fmt.sbprint(b, "<img src=\"", path, "\"></img>", sep = "")
				}
			case .Heading:
				level := cmark.node_get_heading_level(node)
				buf: [1]byte
				str := strconv.write_int(buf[:], i64(level), 10)
				tag := strings.concatenate({"h", str})
				append(&tags, tag)
				fmt.sbprint(b, "<", tag, ">", sep = "")

			case .Link:
				url := strings.clone_from_cstring(cmark.node_get_url(node))
				scheme, host, path, queries, fragment := net.split_url(url)
				path_split, _ := strings.split(host, ".")
				if len(path_split) > 1 && path_split[1] == "youtube" {
					fmt.sbprint(b,
						"</br><iframe width=\"560\" height=\"315\" " +
						"src=\"https://www.youtube.com/embed/", queries["v"], "\" " +
						"title=\"YouTube video player\" frameborder=\"0\" allow=\"accelerometer; autoplay; clipboard-write; encrypted-media; " +
						"gyroscope; picture-in-picture; web-share\" referrerpolicy=\"strict-origin-when-cross-origin\" allowfullscreen></iframe>", sep = "")
					append(&tags, "br")
				} else {
					fmt.sbprint(b, "<a href=\"", url, "\">")
					append(&tags, "a")
				}
			case .List:
				fmt.sbprint(b, "<ul>", sep = "")
				append(&tags, "ul")
			case .Item:
				fmt.sbprint(b, "<li>", sep = "")
				append(&tags, "li")
			case .Code:
				fmt.sbprint(b, "<code>", strings.clone_from_cstring(cmark.node_get_literal(node)), "</code>", sep = "")
			case .Code_Block:
				literal := strings.clone_from_cstring(cmark.node_get_literal(node))
				literal, _ = strings.replace_all(literal, "\t", "    ")
				if language := cmark.node_get_fence_info(node); len(language) > 0 {
					language := strings.clone_from_cstring(language)
					result.languages[language] = true
					fmt.sbprint(b, "<pre><code class=\"language-", language, "\">", literal, "</pre></code>", sep = "")
				} else {
					fmt.sbprint(b, "<pre><code>", literal, "\"</pre></code>", sep = "")
				}
			case .Paragraph:
				append(&tags, "p")
				fmt.sbprint(b, "<p>", sep = "")
			case .Text:
				fmt.sbprint(b, strings.clone_from_cstring(cmark.node_get_literal(node)), sep = "")
			}
		case .Exit:
			#partial switch node_type {
			case .Heading, .Paragraph, .List, .Item, .Link:
				fmt.sbprint(b, "</", pop(&tags), ">", sep = "")
			}
			continue
		}
	}

	return result
}
