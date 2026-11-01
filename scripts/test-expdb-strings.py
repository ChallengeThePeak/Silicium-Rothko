#!/usr/bin/env python3
"""In-memory regression tests; no temporary-file cleanup or device access."""

import importlib.util
from pathlib import Path
import unittest


SPEC = importlib.util.spec_from_file_location(
    "expdb_strings", Path(__file__).with_name("analyze-expdb-strings.py"))
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

PREFIX = (
    b"PL_LOG_STORE:set ram_header->sig = 0xABCD1234\n"
    b"#T#WDT_INIT=2\n"
    b"RAM_CONSOLE wdt status 0x800\n"
    b"#T#Boot dev init=299\n"
    b"[PLFM] Init Boot Device: OK(0)\n"
    b"PL_LOG_STORE early_save_pllog, flag 0x800, reboot count 0x0.\n"
    b"PL_LOG_STORE:save last preload sram log offset 0x44000, size 0x7F76!\n"
)


class ExpdbStringsTests(unittest.TestCase):
    def test_duplicate_prefix_is_not_another_proven_boot(self):
        result = MODULE.analyze_bytes(PREFIX + PREFIX + b"starting app mt_boot\n")
        self.assertEqual(len(result["fragments"]), 2)
        self.assertEqual(result["duplicate_early_prefixes"][0]["fragments"], [1, 2])
        self.assertEqual(result["duplicate_early_prefixes"][0]["line_count"], 7)
        self.assertFalse(result["fragments"][0]["continues_after_early_save"])
        self.assertTrue(result["fragments"][1]["continues_after_early_save"])

    def test_early_save_is_not_a_boot_start(self):
        result = MODULE.analyze_bytes(PREFIX + b"starting app mt_boot\n")
        self.assertEqual(len(result["fragments"]), 1)
        self.assertEqual(result["fragments"][0]["marker_counts"]["lk_mt_boot"], 1)

    def test_normal_boot_can_have_same_wdt_samples(self):
        result = MODULE.analyze_bytes(PREFIX + b"Ready to boot linux...\n"
                                      b"boot_linux_fdt:547: kernel_sz=0x015141fe\n")
        self.assertEqual(result["marker_counts"]["ram_console_reset_status"], 1)
        self.assertEqual(result["marker_counts"]["lk_ready"], 1)
        self.assertFalse(result["fragments"][0]["execution_stop_inferred"])

    def test_missing_handoff_string_does_not_override_probe_pc(self):
        result = MODULE.analyze_bytes(PREFIX + b"CPU PC = 0x40000070\n")
        self.assertEqual(result["marker_counts"]["atf_cpu_pc"], 1)
        self.assertEqual(result["marker_counts"]["lk_final_jump"], 0)
        self.assertFalse(result["fragments"][0]["execution_stop_inferred"])

    def test_flash_adjacency_includes_save_boundary(self):
        data = PREFIX + b"fastboot: flash:boot_a[len:12]\nrebooting the device\n" + PREFIX
        result = MODULE.analyze_bytes(data)
        window = result["flash_adjacent_text"][0]
        self.assertEqual(window["flash_line"], 8)
        self.assertEqual(window["adjacent_text_start_line"], 10)
        self.assertEqual(window["adjacent_text_end_line"], 16)
        self.assertIn("not a validated boot timeline", window["chronology"])

    def test_no_reboot_is_not_fabricated(self):
        result = MODULE.analyze_bytes(PREFIX + b"fastboot: flash:boot_a[len:12]\n")
        self.assertEqual(result["flash_adjacent_text"], [])

    def test_binary_prefix_offsets_remain_text_offsets(self):
        data = b"\0\0" + PREFIX
        result = MODULE.analyze_bytes(data)
        self.assertEqual(result["nul_byte_count"], 2)
        self.assertEqual(result["fragments"][0]["text_offset_end"], len(data))
        self.assertIn("NOT", result["offsets_scope"])

    def test_raw_lastpc_is_separate_from_atf_pc(self):
        result = MODULE.analyze_bytes(PREFIX + b"[LASTPC]CPU0 pc=0xD66D9BC939608AEC\n")
        self.assertEqual(result["marker_counts"]["raw_lastpc"], 1)
        self.assertEqual(result["marker_counts"]["atf_cpu_pc"], 0)

    def test_empty_input_has_no_invented_fragment(self):
        result = MODULE.analyze_bytes(b"")
        self.assertEqual(result["fragments"], [])
        self.assertEqual(result["line_count"], 0)

    def test_different_prefixes_are_not_deduplicated(self):
        result = MODULE.analyze_bytes(PREFIX + PREFIX.replace(b"WDT_INIT=2", b"WDT_INIT=1"))
        self.assertEqual(result["duplicate_early_prefixes"], [])


if __name__ == "__main__":
    unittest.main()
