/*
 * Copyright (C) 2012 Daiki Ueno <ueno@unixuser.org>
 * Copyright (C) 2012 Red Hat, Inc.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
using Gee;

namespace Kkc {
    public class TextBigramDict : Dict, UnigramDict, BigramDict {
        DictEntry _bos;
        public override DictEntry bos {
            get {
                return _bos;
            }
        }

        DictEntry _eos;
        public override DictEntry eos {
            get {
                return _eos;
            }
        }

        protected Gee.Map<string,ArrayList<DictEntry?>> input_map =
            new HashMap<string,ArrayList<DictEntry?>> ();
        protected Gee.Map<string,double?> cost_map =
            new HashMap<string,double?> ();
        protected Gee.Map<string,double?> backoff_map =
            new HashMap<string,double?> ();
        protected Gee.Map<string,uint> id_map =
            new HashMap<string,uint> ();

        public override Collection<DictEntry?> entries (string input) {
            var entries = new ArrayList<DictEntry?> ();
            for (var i = 1; i < input.char_count () + 1; i++) {
                long byte_offset = input.index_of_nth_char (i);
                var str = input.substring (0, byte_offset);
                if (input_map.has_key (str))
                    entries.add_all (input_map.get (str));
            }
            return (Collection<DictEntry?>) entries;
        }

        public override DictEntry? @get (string input, string output) {
            return null;
        }

        protected string get_key (uint[] ids) {
            var builder = new StringBuilder ();
            foreach (var id in ids) {
                builder.append_printf ("%08X", id);
            }
            return builder.str;
        }

        public bool has_bigram (DictEntry pentry, DictEntry entry) {
            var key = get_key (new uint[] { pentry.id, entry.id });
            return cost_map.has_key ((string) key);
        }

        public double unigram_cost (DictEntry entry) {
            var key = get_key (new uint[] { entry.id });
            if (cost_map.has_key (key))
                return cost_map.get (key);
            return 0;
        }

        public double unigram_backoff (DictEntry entry) {
            var key = get_key (new uint[] { entry.id });
            if (backoff_map.has_key (key))
                return backoff_map.get (key);
            return 0;
        }

        public double bigram_cost (DictEntry pentry, DictEntry entry) {
            var key = get_key (new uint[] { pentry.id, entry.id });
            if (cost_map.has_key (key))
                return cost_map.get (key);
            return 0;
        }

        public double bigram_backoff (DictEntry pentry, DictEntry entry) {
            var key = get_key (new uint[] { pentry.id, entry.id });
            if (backoff_map.has_key (key))
                return backoff_map.get (key);
            return 0;
        }

        protected void parse_lm (string input) {
            var lm_file = File.new_for_path (input);
            var lm_data = new DataInputStream (lm_file.read ());

            while (true) {
                size_t length;
                var line = lm_data.read_line (out length);
                if (line == null)
                    break;
                line = line.strip ();
                if (line == "")
                    continue;
                if (line.has_prefix ("\\1-grams:"))
                    break;
            }

            uint id = 0;
            while (true) {
                size_t length;
                var line = lm_data.read_line (out length);
                if (line == null)
                    break;
                line = line.strip ();
                if (line == "" || line.has_prefix ("\\"))
                    continue;

                var strv = line.split ("\t");

                if (!strv[1].contains (" ")) {
                    id_map.set (strv[1], id);

                    string[] input_output;
                    if (strv[1] == "<s>" || strv[1] == "</s>" ||
                        strv[1] == "<UNK>") {
                        input_output = new string[] { " ", strv[1] };
                    } else {
                        input_output = strv[1].split("/");
                    }

                    DictEntry entry = {
                        input_output[0],
                        input_output[1],
                        id++
                    };

                    if (strv[1] == "<s>") {
                        _bos = entry;
                    } else if (strv[1] == "</s>") {
                        _eos = entry;
                    }

                    if (!input_map.has_key (input_output[0]))
                        input_map.set (input_output[0],
                                       new ArrayList<DictEntry?> ());
                    input_map.get (input_output[0]).add (entry);
                }

                double cost = double.parse (strv[0]);
                double backoff = 0.0;
                if (strv.length > 2)
                    backoff = double.parse (strv[2]);

                var words = strv[1].split (" ");
                uint[] ids = {};
                foreach (var word in words) {
                    ids += id_map.get (word);
                }

                string key = get_key (ids);
                cost_map.set (key, cost);
                backoff_map.set (key, backoff);
            }
        }

        public void parse (string prefix) {
            parse_lm (prefix + ".arpa");
        }

        construct {
            parse (Path.build_filename (metadata.base_dir, "data"));
        }
    }
}
