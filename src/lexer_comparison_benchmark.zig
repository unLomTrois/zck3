const std = @import("std");
const original_lexer = @import("lexer.zig");
const simd_lexer = @import("lexer_simd.zig");

// TODO: rewrite because original_lexer is now returns nullable tokens and simd one doesn't

const large_paradox_script =
    \\namespace = "ep3_powerful_families"
    \\
    \\##################################################
    \\#   EP3 Powerful Families
    \\#   by James Beaumont
    \\#   8000        In High Places
    \\#   8010        Emperor in Distress
    \\#   8020        In the Bud
    \\#   8030        Families That Scheme Together...
    \\#   8040        Cordially
    \\#   8050        An Atrocious Appointment
    \\#   8060        A Villainous Villa
    \\#   8070        Folly
    \\#   8080        Stammering Silence
    \\
    \\ep3_powerful_families.8000 = {
    \\    type = character_event
    \\    title = "ep3_powerful_families.8000.t"
    \\    desc = "ep3_powerful_families.8000.desc"
    \\    theme = "administrative"
    \\    left_portrait = {
    \\        character = root
    \\        animation = "thinking"
    \\    }
    \\    right_portrait = {
    \\        character = scope:influential_family_member
    \\        animation = "scheme"
    \\    }
    \\    lower_right_portrait = {
    \\        character = liege
    \\    }
    \\    cooldown = { years = 10 }
    \\
    \\    trigger = {
    \\        government_allows = "administrative"
    \\        house ?= {
    \\            is_powerful_family = yes
    \\        }
    \\        # No Emperors
    \\        is_independent_ruler = no
    \\        liege = { is_ai = yes }
    \\        house = {
    \\            any_house_member = {
    \\                any_court_position_employer = { this = root.liege }
    \\                ai_rationality > ai_honor
    \\            }
    \\        }
    \\    }
    \\
    \\    weight_multiplier = {
    \\        base = 1
    \\        modifier = {
    \\            factor = 2
    \\            gold >= 1000
    \\        }
    \\        modifier = {
    \\            factor = 0.5
    \\            prestige < 500
    \\        }
    \\    }
    \\
    \\    immediate = {
    \\        house = {
    \\            random_house_member = {
    \\                limit = {
    \\                    any_court_position_employer = { this = root.liege }
    \\                    ai_rationality > ai_honor
    \\                }
    \\                save_scope_as = influential_family_member
    \\            }
    \\        }
    \\        liege = { save_scope_as = liege } # for loc
    \\    }
    \\
    \\    # Spread our influence like a weed
    \\    option = {
    \\        name = "ep3_powerful_families.8000.a"
    \\        scope:influential_family_member = {
    \\            duel = {
    \\                skill = intrigue
    \\                target = root.liege
    \\                50 = {
    \\                    compare_modifier = {
    \\                        value = scope:duel_value
    \\                        multiplier = 3.5
    \\                        min = -49
    \\                    }
    \\                    root = {
    \\                        send_interface_toast = {
    \\                            title = "ep3_powerful_families.8000.a.win"
    \\                            left_icon = root
    \\                            right_icon = scope:influential_family_member
    \\                            change_influence = medium_influence_gain
    \\                        }
    \\                    }
    \\                }
    \\                25 = {
    \\                    desc = "ep3_powerful_families.8000.a.partial"
    \\                    root = {
    \\                        change_gold = 250
    \\                        change_prestige = 100
    \\                    }
    \\                }
    \\                25 = {
    \\                    desc = "ep3_powerful_families.8000.a.fail"
    \\                    root = {
    \\                        change_gold = -150
    \\                        change_prestige = -75
    \\                    }
    \\                }
    \\            }
    \\        }
    \\    }
    \\    
    \\    option = {
    \\        name = "ep3_powerful_families.8000.b"
    \\        trigger = {
    \\            gold >= 2000
    \\            prestige >= 750
    \\        }
    \\        root = {
    \\            change_gold = -500
    \\            change_influence = 150
    \\            add_character_modifier = {
    \\                modifier = "political_maneuvering"
    \\                years = 5
    \\            }
    \\        }
    \\    }
    \\}
    \\
    \\scripted_effect ep3_pf_8010_a_effect = {
    \\    scope:generous_family = {
    \\        pay_short_term_gold = {
    \\            target = liege
    \\            gold = medium_gold_value
    \\        }
    \\        change_influence = medium_influence_gain
    \\    }
    \\}
    \\
    \\scripted_trigger has_enough_gold = {
    \\    gold >= 500
    \\    NOT = { has_trait = "greedy" }
    \\    any_councilor = {
    \\        has_council_task = "task_manage_finances"
    \\        opinion = { target = root value >= 25 }
    \\    }
    \\}
    \\
    \\# Additional content with more numbers and strings
    \\character_modifier political_maneuvering = {
    \\    monthly_prestige = 2.5
    \\    monthly_influence = 1.25
    \\    intrigue = 3
    \\    diplomacy = 2
    \\    icon = "gfx/interface/icons/modifiers/political_modifier.dds"
    \\    desc = "political_maneuvering_desc"
    \\}
    \\
    \\trait_group family_traits = {
    \\    traits = {
    \\        "influential_family_member" = {
    \\            value = 100
    \\            intrigue = 5
    \\            diplomacy = 3
    \\            monthly_prestige = 1.0
    \\        }
    \\        "family_patriarch" = {
    \\            value = 200
    \\            stewardship = 4
    \\            learning = 2
    \\            monthly_gold = 25.5
    \\        }
    \\        "family_schemer" = {
    \\            value = 150
    \\            intrigue = 8
    \\            monthly_influence = 2.75
    \\            opinion_same_trait = 10
    \\        }
    \\    }
    \\}
    \\
    \\building_type family_estate = {
    \\    cost = { gold = 1500 }
    \\    construction_time = 365
    \\    max_count = 1
    \\    
    \\    modifier = {
    \\        monthly_income = 12.5
    \\        levy_size = 0.15
    \\        development_growth = 0.05
    \\    }
    \\    
    \\    can_construct = {
    \\        holder = {
    \\            house ?= {
    \\                is_powerful_family = yes
    \\                house_unity >= 75
    \\            }
    \\            gold >= 2000
    \\            prestige >= 1000
    \\        }
    \\    }
    \\    
    \\    desc = "family_estate_desc"
    \\    picture = "gfx/buildings/family_estate.dds"
    \\}
;

const BenchmarkResult = struct {
    name: []const u8,
    iterations: u32,
    total_time_ns: u64,
    total_tokens: usize,
    avg_time_ms: f64,
    throughput_mb_s: f64,
    tokens_per_second: f64,
};

fn benchmarkLexer(
    comptime LexerType: type,
    lexer_name: []const u8,
    test_input: []const u8,
    iterations: u32,
) !BenchmarkResult {
    var timer = try std.time.Timer.start();
    var total_tokens: usize = 0;

    for (0..iterations) |_| {
        var lex = LexerType.init(test_input);
        var token_count: usize = 0;

        while (true) {
            const token = lex.next();
            token_count += 1;
            if (token.tag == .eof) break;
        }
        total_tokens += token_count;
    }

    const elapsed_ns = timer.read();
    const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
    const avg_ms = elapsed_ms / @as(f64, @floatFromInt(iterations));
    const throughput_mb_s = (@as(f64, @floatFromInt(test_input.len)) / (1024.0 * 1024.0)) / (avg_ms / 1000.0);
    const tokens_per_second = @as(f64, @floatFromInt(total_tokens)) / (elapsed_ms / 1000.0);

    return BenchmarkResult{
        .name = lexer_name,
        .iterations = iterations,
        .total_time_ns = elapsed_ns,
        .total_tokens = total_tokens,
        .avg_time_ms = avg_ms,
        .throughput_mb_s = throughput_mb_s,
        .tokens_per_second = tokens_per_second,
    };
}

fn printBenchmarkResult(result: BenchmarkResult) void {
    std.log.info("=== {s} Results ===", .{result.name});
    std.log.info("  Iterations: {d}", .{result.iterations});
    std.log.info("  Total time: {d:.2} ms", .{@as(f64, @floatFromInt(result.total_time_ns)) / 1_000_000.0});
    std.log.info("  Average per iteration: {d:.4} ms", .{result.avg_time_ms});
    std.log.info("  Throughput: {d:.2} MB/s", .{result.throughput_mb_s});
    std.log.info("  Tokens processed: {d}", .{result.total_tokens});
    std.log.info("  Tokens per second: {d:.0}", .{result.tokens_per_second});
}

fn printComparison(original: BenchmarkResult, simd: BenchmarkResult) void {
    const speedup_ratio = original.avg_time_ms / simd.avg_time_ms;
    const throughput_improvement = (simd.throughput_mb_s - original.throughput_mb_s) / original.throughput_mb_s * 100.0;
    const tokens_improvement = (simd.tokens_per_second - original.tokens_per_second) / original.tokens_per_second * 100.0;

    std.log.info("", .{});
    std.log.info("=== PERFORMANCE COMPARISON ===", .{});
    std.log.info("SIMD vs Original Performance:", .{});
    std.log.info("  Speed improvement: {d:.2}x faster", .{speedup_ratio});
    std.log.info("  Throughput improvement: +{d:.1}%", .{throughput_improvement});
    std.log.info("  Token processing improvement: +{d:.1}%", .{tokens_improvement});
    std.log.info("  Time saved per iteration: {d:.4} ms", .{original.avg_time_ms - simd.avg_time_ms});

    if (speedup_ratio >= 2.0) {
        std.log.info("  🚀 EXCELLENT: >2x speedup!", .{});
    } else if (speedup_ratio >= 1.5) {
        std.log.info("  ✅ GOOD: >1.5x speedup", .{});
    } else if (speedup_ratio >= 1.2) {
        std.log.info("  ✓ MODERATE: >1.2x speedup", .{});
    } else {
        std.log.info("  ⚠️ MINIMAL: <1.2x speedup", .{});
    }
}

fn runScalingTest() !void {
    const allocator = std.heap.page_allocator;
    const base_size = large_paradox_script.len;
    const test_sizes = [_]usize{ 1, 10, 100, 500, 1000 };

    std.log.info("", .{});
    std.log.info("=== SCALING TEST (Different Input Sizes) ===", .{});

    for (test_sizes) |multiplier| {
        const total_size = base_size * multiplier;
        var large_input = try allocator.alloc(u8, total_size);
        defer allocator.free(large_input);

        // Fill with repeated content
        var offset: usize = 0;
        for (0..multiplier) |_| {
            @memcpy(large_input[offset .. offset + base_size], large_paradox_script);
            offset += base_size;
        }

        var iterations: u32 = 10;
        if (multiplier <= 10) {
            iterations = 50;
        } else if (multiplier <= 100) {
            iterations = 20;
        }

        const original_result = try benchmarkLexer(original_lexer.Lexer, "Original", large_input, iterations);
        const simd_result = try benchmarkLexer(simd_lexer.Lexer, "SIMD", large_input, iterations);

        const speedup = original_result.avg_time_ms / simd_result.avg_time_ms;

        std.log.info("Size: {d:.1} KB | Original: {d:.2} MB/s | SIMD: {d:.2} MB/s | Speedup: {d:.2}x", .{
            @as(f64, @floatFromInt(total_size)) / 1024.0,
            original_result.throughput_mb_s,
            simd_result.throughput_mb_s,
            speedup,
        });
    }
}

fn runDetailedAnalysis(test_input: []const u8) !void {
    std.log.info("", .{});
    std.log.info("=== DETAILED ANALYSIS ===", .{});
    std.log.info("Input characteristics:", .{});
    std.log.info("  Total size: {d} bytes ({d:.1} KB)", .{ test_input.len, @as(f64, @floatFromInt(test_input.len)) / 1024.0 });

    // Analyze character distribution
    var char_counts = [_]usize{0} ** 256;
    for (test_input) |c| {
        char_counts[c] += 1;
    }

    const total_chars = test_input.len;
    const whitespace_count = char_counts[' '] + char_counts['\t'] + char_counts['\n'] + char_counts['\r'];
    const identifier_chars = blk: {
        var count: usize = 0;
        for ('a'..('z' + 1)) |c| count += char_counts[c];
        for ('A'..('Z' + 1)) |c| count += char_counts[c];
        for ('0'..('9' + 1)) |c| count += char_counts[c];
        count += char_counts['_'];
        break :blk count;
    };

    std.log.info("  Whitespace: {d:.1}%", .{@as(f64, @floatFromInt(whitespace_count)) / @as(f64, @floatFromInt(total_chars)) * 100.0});
    std.log.info("  Identifier chars: {d:.1}%", .{@as(f64, @floatFromInt(identifier_chars)) / @as(f64, @floatFromInt(total_chars)) * 100.0});
    std.log.info("  Comments (#): {d} occurrences", .{char_counts['#']});
    std.log.info("  Strings (\"): {d} occurrences", .{char_counts['"']});

    // Sample token analysis
    var sample_lexer = simd_lexer.Lexer.init(test_input[0..@min(200, test_input.len)]);
    std.log.info("  Sample tokens (first 200 bytes):", .{});

    var token_count: usize = 0;
    while (token_count < 10) {
        const token = sample_lexer.next();
        if (token.tag == .eof) break;

        const value = token.getValue(test_input[0..@min(200, test_input.len)]);
        const truncated_value = if (value.len > 20) value[0..17] ++ "..." else value;
        std.log.info("    {s}: '{s}'", .{ @tagName(token.tag), truncated_value });
        token_count += 1;
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.log.info("ParadoxScript Lexer Performance Comparison", .{});
    std.log.info("==========================================", .{});

    // Create test input by repeating the content
    const repetitions = 1000;
    const total_size = large_paradox_script.len * repetitions;
    var large_input = try allocator.alloc(u8, total_size);
    defer allocator.free(large_input);

    var offset: usize = 0;
    for (0..repetitions) |_| {
        @memcpy(large_input[offset .. offset + large_paradox_script.len], large_paradox_script);
        offset += large_paradox_script.len;
    }

    std.log.info("Test input: {d} bytes ({d:.1} MB) of ParadoxScript", .{ total_size, @as(f64, @floatFromInt(total_size)) / (1024.0 * 1024.0) });

    // Run detailed analysis
    try runDetailedAnalysis(large_input);

    // Benchmark both lexers
    const iterations = 50;

    std.log.info("", .{});
    std.log.info("Running {d} iterations on each lexer...", .{iterations});

    const original_result = try benchmarkLexer(original_lexer.Lexer, "Original (Character-by-Character)", large_input, iterations);
    printBenchmarkResult(original_result);

    std.log.info("", .{});

    const simd_result = try benchmarkLexer(simd_lexer.Lexer, "SIMD-Optimized (16-byte Vectors)", large_input, iterations);
    printBenchmarkResult(simd_result);

    // Print comparison
    printComparison(original_result, simd_result);

    // Run scaling test
    try runScalingTest();

    // Verification test
    std.log.info("", .{});
    std.log.info("=== CORRECTNESS VERIFICATION ===", .{});
    const test_input = "namespace = test\nkey = { value = 123 }\n# comment\n";

    var orig_lex = original_lexer.Lexer.init(test_input);
    var simd_lex = simd_lexer.Lexer.init(test_input);

    var tokens_match = true;
    var token_index: usize = 0;
    while (true) {
        const orig_token = orig_lex.next();
        const simd_token = simd_lex.next();

        // Compare tag names as strings since enums are from different modules
        const orig_tag_name = @tagName(orig_token.tag);
        const simd_tag_name = @tagName(simd_token.tag);

        if (!std.mem.eql(u8, orig_tag_name, simd_tag_name) or orig_token.start != simd_token.start or orig_token.end != simd_token.end) {
            std.log.err("Token mismatch at index {d}:", .{token_index});
            std.log.err("  Original: {s} [{d}..{d}]", .{ orig_tag_name, orig_token.start, orig_token.end });
            std.log.err("  SIMD:     {s} [{d}..{d}]", .{ simd_tag_name, simd_token.start, simd_token.end });
            tokens_match = false;
            break;
        }

        if (std.mem.eql(u8, orig_tag_name, "eof")) break;
        token_index += 1;
    }

    if (tokens_match) {
        std.log.info("✅ PASSED: Both lexers produce identical token sequences", .{});
    } else {
        std.log.err("❌ FAILED: Token sequences differ between lexers", .{});
    }

    std.log.info("", .{});
    std.log.info("=== SUMMARY ===", .{});
    std.log.info("The SIMD optimizations provide {d:.1}x speedup for ParadoxScript lexing", .{original_result.avg_time_ms / simd_result.avg_time_ms});
    std.log.info("This improvement comes from vectorized operations for:", .{});
    std.log.info("  • Whitespace skipping (spaces, tabs, newlines)", .{});
    std.log.info("  • Identifier character scanning (a-z, A-Z, 0-9, _)", .{});
    std.log.info("  • Number digit scanning (0-9)", .{});
    std.log.info("  • String quote searching", .{});
    std.log.info("  • Comment newline detection", .{});
}
