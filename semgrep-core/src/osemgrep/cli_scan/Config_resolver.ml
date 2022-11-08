(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)
(*
   Partially translated from config_resolver.py

   TODO:
    - handle the registry-aware jsonnet format (LONG)
    - lots of stuff ...
 *)

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

(* python: was called ConfigFile, and called a 'config' in text output *)
type rules_and_origin = {
  path : Common.filename option; (* None for remote files *)
  (* TODO? put a config_id: string option? or config prefix *)
  rules : Rule.rules;
  errors : Rule.invalid_rule_error list;
}

(*****************************************************************************)
(* Entry point *)
(*****************************************************************************)

let load_rules_from_file file : rules_and_origin =
  Logs.debug (fun m -> m "loading local config from %s" file);
  let rules, errors = Parse_rule.parse_and_filter_invalid_rules file in
  { path = Some file; rules; errors }

let load_rules_from_url url : rules_and_origin =
  Logs.debug (fun m -> m "trying to download from %s" (Uri.to_string url));
  let content = Network.get url in
  Common2.with_tmp_file ~str:content ~ext:"yaml" (fun file ->
      let res = load_rules_from_file file in
      { res with path = None })

let rules_from_dashdash_config (config_str : string) : rules_and_origin list =
  let kind = Semgrep_dashdash_config.config_kind_of_config_str config_str in
  match kind with
  | File file -> [ load_rules_from_file file ]
  | Dir dir ->
      List_files.list dir
      (* TOPORT:
         and not _is_hidden_config(l.relative_to(loc))
         ...
         def _is_hidden_config(loc: Path) -> bool:
         """
         Want to keep rules/.semgrep.yml but not path/.github/foo.yml
         Also want to keep src/.semgrep/bad_pattern.yml but not ./.pre-commit-config.yaml
         """
         return any(
           part != os.curdir
           and part != os.pardir
           and part.startswith(".")
           and DEFAULT_SEMGREP_CONFIG_NAME not in part
           for part in loc.parts
         )
      *)
      |> List.filter Parse_rule.is_valid_rule_filename
      |> Common.map load_rules_from_file
  | URL url -> [ load_rules_from_url url ]
  | R rkind ->
      let url = Semgrep_dashdash_config.url_of_registry_kind rkind in
      [ load_rules_from_url url ]