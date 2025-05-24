const std = @import("std");
const lexer = @import("lexer_simd.zig");

const large_paradox_script =
    \\namespace = ep3_powerful_families
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
    \\    title = ep3_powerful_families.8000.t
    \\    desc = ep3_powerful_families.8000.desc
    \\    theme = administrative
    \\    left_portrait = {
    \\        character = root
    \\        animation = thinking
    \\    }
    \\    right_portrait = {
    \\        character = scope:influential_family_member
    \\        animation = scheme
    \\    }
    \\    lower_right_portrait = {
    \\        character = liege
    \\    }
    \\    cooldown = { years = 10 }
    \\
    \\    trigger = {
    \\        government_allows = administrative
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
    \\        name = ep3_powerful_families.8000.a
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
    \\                            title = ep3_powerful_families.8000.a.win
    \\                            left_icon = root
    \\                            right_icon = scope:influential_family_member
    \\                            change_influence = medium_influence_gain
    \\                        }
    \\                    }
    \\                }
    \\            }
    \\        }
    \\    }
    \\}
;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // Create a large test input by repeating the ParadoxScript content
    const repetitions = 10000;
    const total_size = large_paradox_script.len * repetitions;
    const large_input = try arena.allocator().alloc(u8, total_size);
    defer arena.allocator().free(large_input);

    var offset: usize = 0;
    for (0..repetitions) |_| {
        @memcpy(large_input[offset .. offset + large_paradox_script.len], large_paradox_script);
        offset += large_paradox_script.len;
    }

    std.log.info("Benchmarking SIMD-optimized lexer on {d} bytes of ParadoxScript", .{total_size});

    // Benchmark the SIMD lexer
    const iterations = 100;
    var timer = try std.time.Timer.start();

    for (0..iterations) |_| {
        var lex = lexer.Lexer.init(large_input);
        var token_count: usize = 0;

        while (true) {
            const token = lex.next();
            token_count += 1;
            if (token.tag == .eof) break;
        }
    }

    const elapsed_ns = timer.read();
    const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
    const avg_ms = elapsed_ms / @as(f64, @floatFromInt(iterations));
    const throughput_mb_s = (@as(f64, @floatFromInt(total_size)) / (1024.0 * 1024.0)) / (avg_ms / 1000.0);

    std.log.info("Processed {d} iterations in {d:.2} ms", .{ iterations, elapsed_ms });
    std.log.info("Average time per iteration: {d:.4} ms", .{avg_ms});
    std.log.info("Throughput: {d:.2} MB/s", .{throughput_mb_s});

    // Sample a small portion to verify tokens are being generated correctly
    var sample_lexer = lexer.Lexer.init(large_paradox_script[0..100]);
    std.log.info("Sample tokens from first 100 bytes:", .{});
    for (0..10) |_| {
        const token = sample_lexer.next();
        const value = token.getValue(large_paradox_script[0..100]);
        std.log.info("  {s}: '{s}'", .{ @tagName(token.tag), value });
        if (token.tag == .eof) break;
    }
}
