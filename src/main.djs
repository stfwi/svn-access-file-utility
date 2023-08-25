#!/usr/bin/djs -s
/**
 * @file main.djs
 * @author Stefan Wilhelm (stfwi)
 * @license MIT
 * @std ES5, duktape-cc extensions.
 *
 * SVN access file analysis and sanitizing utility.
 *
 *  Run with djs -s <script> <script-arguments>
 */
const program_name = "svn-access";
const program_version = "v1.0";

const settings = {
  as_json: false,         // Output JSON
  json_inline: false,     // No JSON pretty print
  remove_comments: false  // Remove/ignore comments
};

function pass(message)  { alert("[pass]", message); }
function warn(message)  { alert("[warn]", message); }
function fail(message)  { alert("[fail]", message); }
function bail(message)  { alert("[FAIL]", message); }
function info(message)  { alert("[info]", message); }
function verb(message)  { alert("[verb]", message); }
function dump(what)     { alert("[dump]", JSON.stringify(what,null,1)) ;}

const util = {

  shell_arg: function(args, arg, default_value) {
    var re=new RegExp("[-]*"+arg+"(=|$)");
    for(var i in args) {
      if(args[i] === "--") break; // unix convention: no options after "--", only positional args.
      if(args[i].search(re)===0) {
        var r = args[i].replace(re, "");
        if(args[i].search("=")<0) r=true; // flag
        while(++i<args.length) args[i-1]=args[i];
        args.length--;
        return r;
      }
    }
    return default_value;
  },

  clone: function(data) {
    return JSON.parse(JSON.stringify(data));
  },

  json: function(data) {
    return (!settings.json_inline) ? JSON.stringify(data, null, 1) : JSON.stringify(data);
  },

  svn_read_from_arg0: function(args, options)
  {
    if(!args.length) throw new Error("You need to specify a path to a svn access file.");
    const path = (args.shift()||"").trim();
    if(path=="") throw new Error("Path to svn access file is empty.");
    contents = fs.read(path);
    if(contents===undefined) throw new Error("Failed to read file '"+path+"'");
    return util.svn_parse(contents, options);
  },

  svn_parse: function(contents, options)
  {
    options = options || {};
    if(options.split_users===undefined) options.split_users=true; // default: with user splitting.
    if(options.remove_comments===undefined) options.remove_comments=false; // default: leave comments.
    try {
      contents = contents.split(/\r?\n/);
    } catch(ex) {
      throw new Error("File encoding is not utf8 compliant. Cannot safely process file '"+path+"'.");
    }
    try {
      contents = contents.map(function(line){return line.trim()}).filter(function(line){return line!="";});
    } catch(ex) {
      throw new Error("Failed to pre-process lines of file '"+path+"': " + ex.message);
    }
    const sections = {"":{}};
    var line_no = 0;
    var section_name = ""; // Initial, no section yet.
    var section = sections[section_name];
    while(contents.length > 0) {
      ++line_no;
      const line = contents.shift();
      if(line.search(/^\[/) === 0) {
        section_name = line.replace(/^\[/,"").replace(/\]$/,"");
        if(section_name.trim() != section_name) warn("Section contains leading or trailing whitespaces: '"+line+"' (line "+line_no+").");
        if((sections[section_name] !== undefined) || (sections[section_name.trim()] !== undefined)) throw new Error("Section already exists: '"+line+"' (line "+line_no+")");
        sections[section_name] = {};
        section = sections[section_name];
      } else if(line.search(/^\s*#/) === 0) {
        if(options.remove_comments) {
          info("Ignoring comment: '"+line+"', (line "+line_no+").");
        } else {
          section["#"+line_no] = line;
        }
      } else {
        kv = line.split(/=/);
        if(kv.length >= 2) {
          const key = kv.shift().replace(/\s+$/,"");
          const val = kv.join("=").replace(/^\s+/,"");
          if(key == "") warn("Assignment without a key, only a value: '"+line+"', (line "+line_no+").");
          if(section[key] !== undefined) warn("Key '"+key+"' already exists in section '"+section_name+"', (line "+line_no+"). Overwriting old key.");
          section[key] = val;
        } else if(kv.length === 1) {
          warn("Line is no assignment, but also no comment, ignoring: '"+line+"', (line "+line_no+").");
        } else {
          throw new Error("Unexpectedly split multiple '=' separations (bug, line "+line_no+").");
        }
      }
    }
    if(Object.keys(sections[""]).length === 0) delete sections[""];
    if(sections["groups"] === undefined) {
      verb("File has no section 'groups', that is unusual.");
    } else if(options.split_users === true) {
      const groups = sections["groups"];
      for(var group_name in groups) {
        if(group_name.search(/^#/)===0) continue; // comment.
        groups[group_name] = groups[group_name].split(/,/).map(function(s){return s.trim()}).filter(function(s){return s!=""})
      }
    }
    if(sections["aliases"] !== undefined) {
      if(options.split_users === true) {
        const aliases = sections["aliases"];
        for(var name in aliases) {
          if(name.search(/^#/)===0) continue; // comment.
          aliases[name] = aliases[name].trim();
        }
      }
    }
    return sections;
  },

  svn_compose: function(sections)
  {
    const lines = [];
    if(sections[""] !== undefined) {
      const header_comments = sections[""];
      delete sections[""];
      for(var key in header_comments) {
        lines.push(header_comments[key]);
      }
    }
    if(sections["aliases"] !== undefined) {
      const aliases = sections["aliases"];
      delete sections["aliases"];
      lines.push("");
      lines.push("[aliases]");
      for(var name in aliases) {
        if(name.search(/^#/)<0) {
          lines.push(name + " = " + aliases[name]);
        } else {
          lines.push(aliases[name]); // comment.
        }
      }
    }
    if(sections["groups"] !== undefined) {
      const groups = sections["groups"];
      delete sections["groups"];
      lines.push("");
      lines.push("[groups]");
      for(var group_name in groups) {
        if(group_name.search(/^#/)<0) {
          lines.push(group_name + " = " + groups[group_name].join(", "));
        } else {
          lines.push(groups[group_name]); // comment.
        }
      }
    }
    for(var section_name in sections) {
      const section = sections[section_name];
      lines.push("");
      lines.push("["+section_name+"]");
      for(var key in section) {
        if(key.search(/^#/)<0) {
          lines.push(key + " = " + section[key]);
        } else {
          lines.push(section[key]); // comment
        }
      }
    }
    return lines.join("\n");
  },

  svn_remove_comments: function(sections) {
    if(sections[""]!==undefined) delete sections[""]; // Header comments.
    for(var section_name in sections) {
      const section = sections[section_name];
      const comment_keys = Object.keys(section).filter(function(key){ return key.search(/^#/)===0; });
      comment_keys.filter(function(key){ delete section[key]; });
    }
    return sections;
  }
};

/**
 * Read handler. Prints warnings to stderr, prints
 * the parsed file structure as JSON to stdout.
 * @param {array} args
 * @return {number}
 */
function command_read(args)
{
  print(util.json(util.svn_remove_comments(util.svn_read_from_arg0(args, settings))));
  return 0;
}

/**
 * Sort handler. Prints warnings to stderr, prints
 * the parsed sections sorted by name and length,
 * [groups] and [aliases] first.
 * @param {array} args
 * @return {number}
 */
function command_sort(args)
{
  const sections = util.svn_read_from_arg0(args, settings);
  const out_sections = {};
  if(sections[""] !== undefined) { out_sections[""] = sections[""]; delete sections[""]; } // prepend header comments if applicable
  if(sections["aliases"] !== undefined) { out_sections["aliases"] = sections["aliases"]; delete sections["aliases"]; } // prepend aliases if applicable.
  if(sections["groups"] !== undefined) { out_sections["groups"] = sections["groups"]; delete sections["groups"]; } // prepend groups if applicable.
  const section_names = Object.keys(sections);
  section_names.sort();
  section_names.filter(function(name){ out_sections[name] = sections[name]; }); // JS objects are ordered.
  if(settings.as_json) {
    print(util.json(util.svn_remove_comments(out_sections)));
  } else {
    print(util.svn_compose(out_sections));
  }
  return 0;
}

/**
 * Sections handler. Prints warnings to stderr, prints
 * a all section names of the parsed file.
 * @param {array} args
 * @return {number}
 */
function command_sections(args)
{
  const sections = Object.keys(util.svn_read_from_arg0(args, settings)).filter(function(name){return name!==""});
  sections.sort();
  if(settings.as_json) {
    print(util.json(sections));
  } else {
    sections.filter(function(section){ print(section); });
  }
  return 0;
}

/**
 * Groups handler. Prints warnings to stderr, prints
 * a the [groups] section contents of the parsed file.
 * @param {array} args
 * @return {number}
 */
function command_groups(args)
{
  const sections = util.svn_remove_comments(util.svn_read_from_arg0(args, settings));
  args = args.map(function(arg){return arg.toLowerCase()}).filter(function(arg){return arg.trim()!=""});
  if(sections["groups"] === undefined) throw new Error("Did not find the [groups] section in the access file.");
  const groups = sections["groups"];
  const to_remove = (!args.length) ? ([]) : Object.keys(groups).filter(function(grp){ return args.indexOf(grp.toLowerCase())<0 });
  to_remove.filter(function(grp){ delete groups[grp]; });
  if(settings.as_json) {
    print(util.json(groups));
  } else {
    print("groups");
    for(var group_name in groups) {
      const members = groups[group_name];
      print(" |- " + group_name);
      members.sort();
      members.filter(function(member){ print(" |  |- " + member); });
      print(" |");
    }
  }
  return 0;
}

/**
 * Group handler. Prints warnings to stderr, prints
 * occurrences the given group names in the parsed file.
 * @param {array} args
 * @return {number}
 */
function command_group(args)
{
  const sections = util.svn_remove_comments(util.svn_read_from_arg0(args, settings));
  if(sections["aliases"] !== undefined) delete sections["aliases"];
  args = args.map(function(arg){return arg.toLowerCase()}).filter(function(arg){return arg.trim()!=""});
  if(sections["groups"] !== undefined) {
    const groups = sections["groups"];
    Object.keys(groups).filter(function(grp){ return args.indexOf(grp.toLowerCase())<0 }).filter(function(grp){ delete groups[grp]; });
  }
  const needles = args.map(function(arg){return "@"+arg});
  Object.keys(sections).forEach(function(section_name){
    if(section_name=="groups") return;
    const section = sections[section_name];
    Object.keys(section).filter(function(grp){ return needles.indexOf(grp.toLowerCase())<0 }).filter(function(grp){ delete section[grp]; }); // rm non-matching
    if(!Object.keys(section).length) delete sections[section_name];
  });
  if(settings.as_json) {
    print(util.json(sections));
  } else {
    print(util.svn_compose(sections));
  }
  return 0;
}

/**
 * User handler. Prints warnings to stderr, prints
 * occurrences the given user names in the parsed file.
 * @param {array} args
 * @return {number}
 */
function command_user(args)
{
  const sections = util.svn_remove_comments(util.svn_read_from_arg0(args, settings));
  args = args.map(function(arg){return arg.toLowerCase()}).filter(function(arg){return arg.trim()!=""});
  const needles = util.clone(args);
  if(sections["aliases"] !== undefined) {
    const aliases = sections["aliases"];
    Object.keys(aliases)
      .filter(function(usr){ return needles.indexOf(aliases[usr].toLowerCase())<0 })
      .filter(function(usr){ delete aliases[usr]; });
    Object.keys(aliases).map(function(alias){return "$"+alias}).filter(function(alias){needles.push(alias)});
  }
  if(sections["groups"] !== undefined) {
    const groups = sections["groups"];
    Object.keys(groups).map(function(grp){
      groups[grp] = groups[grp].filter(function(usr){ return needles.indexOf(usr.toLowerCase())>=0 });
      if(groups[grp].length==0) delete groups[grp];
    });
    Object.keys(groups).map(function(grp){return "@"+grp}).filter(function(grp){needles.push(grp)});
  }
  Object.keys(sections).forEach(function(section_name){
    if((section_name == "groups") || (section_name == "aliases")) return;
    const section = sections[section_name];
    Object.keys(section)
      .filter(function(key){ return needles.indexOf(key.toLowerCase())<0 })
      .filter(function(key){ delete section[key]; }); // rm non-matching
    if(!Object.keys(section).length) delete sections[section_name];
  });
  if(settings.as_json) {
    print(util.json(sections));
  } else {
    print(util.svn_compose(sections));
  }
  return 0;
}

/**
 * Help handler (--help|-h|help)
 * @param {array} args
 * @return {number}
 */
function command_help(args)
{
  alert("");
  alert("Usage: " + program_name + " [options] <command> <file> [args...]");
  alert("");
  alert("   SVN access file analysis and sanitizing utility.");
  alert("");
  alert("Options:");
  alert("");
  alert(" --json           Output JSON format with pretty-print.");
  alert(" --json-inline    Output JSON format without pretty-printing.");
  alert(" --no-comments    Ignore comments while parsing a file.");
  alert("");
  alert("Commands:");
  alert("");
  alert(" - read <file>");
  alert("            Reads a file, prints a JSON representation to stdout.");
  alert("");
  alert(" - sections <file>");
  alert("            Lists all section names in a file.");
  alert("");
  alert(" - sort <file>");
  alert("            Prints all sections in a file, sorted by section name");
  alert("            and length. [groups] is always listed first.");
  alert("");
  alert(" - groups <file> [search [terms]]");
  alert("            Lists all groups in a file (or all containing at least");
  alert("            one of the search terms, case insensitive).");
  alert("");
  alert(" - group <file> <match1> [match2 [...]]");
  alert("            Prints all sections in a file, which contain at least");
  alert("            one of the group names to match (case insensitive).");
  alert("");
  alert(" - user <file> <match1> [match2 [...]]");
  alert("            Prints all sections in a file, which contain at least");
  alert("            one of the user names to match (case insensitive).");
  alert("            Only entries with matches are shown, also non-matching");
  alert("            users are removed from groups.");
  alert("");
  alert(" " + program_name + " " + program_version + ", stfwi 2023. License: MIT, free to use.");
  return 0;
}
function command__h(args) { return command_help(args); } // -h
function command___help(args) { return command_help(args); } // --help

/**
 * Main entry point.
 * @param {array} args
 * @returns {number}
 */
function main(args)
{
  args = args || [];
  settings.json_inline |= util.shell_arg(args, "json-inline", false);
  settings.as_json |= util.shell_arg(args, "json", false) || settings.json_inline;
  settings.remove_comments |= util.shell_arg(args, "no-comments", false);
  const cmd = (!args.length) ? ("") : (args.shift().replace(/^\s+/,"").replace(/\s+$/,"").toLowerCase());
  if(cmd == "") { alert(program_name + ": Command missing, try '" + program_name + " --help'"); return 1; }
  if((!args.length) && (cmd=="--help") || (cmd=="-h")) return command_help();
  try {
    if(typeof(global["command_"+cmd]) === "function") {
      return global["command_"+cmd](args);
    } else {
      alert("Unknown command '" + cmd + "', try --help");
      return 1;
    }
  } catch(ex) {
    fail(ex.message);
    if(sys.app.verbose) verb(ex.stack);
    return 1;
  }
}
