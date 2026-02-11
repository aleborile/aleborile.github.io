<script lang="ts">
  import * as Card from "$lib/components/ui/card";
  import * as Chart from "$lib/components/ui/chart";
  import {
    Area,
    AreaChart,
    ChartClipPath,
    Axis,
    Highlight,
    Spline,
    Svg,
    Tooltip,
  } from "layerchart";
  import { scaleUtc } from "d3-scale";
  import { curveNatural } from "d3-shape";
  import { cubicInOut } from "svelte/easing";

  // Birth date reference: month 0 = December 11, 2025
  const birthDate = new Date(2025, 11, 11);

  // Calculate current month based on browser's current date
  const currentMonth = $derived.by(() => {
    const now = new Date(); // Uses browser's current date
    const diffMs = now.getTime() - birthDate.getTime();
    const diffDays = diffMs / (1000 * 60 * 60 * 24);
    return diffDays / 30.44; // Average days per month
  });

  // Get calendar month name from chart month (0 = December)
  function getCalendarMonth(chartMonth: number): string {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    // Month 0 = December, so we offset by 11
    const calendarMonthIndex = (11 + Math.round(chartMonth)) % 12;
    return months[calendarMonthIndex];
  }

  function getFullCalendarMonth(chartMonth: number): string {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    const calendarMonthIndex = (11 + Math.round(chartMonth)) % 12;
    return months[calendarMonthIndex];
  }

  // WHO Length-for-age percentile data (boys, 0-24 months) in cm
  const whoPercentiles = {
    months: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 15, 18, 21, 24],
    p3: [
      46.1, 50.8, 54.4, 57.3, 59.7, 61.7, 63.3, 64.8, 66.2, 67.5, 68.7, 69.9,
      71.0, 73.6, 76.0, 78.3, 80.5,
    ],
    p15: [
      47.9, 52.7, 56.4, 59.4, 61.8, 63.8, 65.5, 67.0, 68.4, 69.7, 71.0, 72.2,
      73.4, 76.1, 78.6, 81.0, 83.3,
    ],
    p50: [
      49.9, 54.7, 58.4, 61.4, 63.9, 65.9, 67.6, 69.2, 70.6, 72.0, 73.3, 74.5,
      75.7, 78.5, 81.1, 83.5, 85.9,
    ],
    p85: [
      51.8, 56.7, 60.4, 63.5, 66.0, 68.0, 69.8, 71.3, 72.8, 74.2, 75.5, 76.9,
      78.0, 81.0, 83.6, 86.1, 88.5,
    ],
    p97: [
      53.7, 58.6, 62.4, 65.5, 68.0, 70.1, 71.9, 73.5, 74.9, 76.4, 77.8, 79.2,
      80.3, 83.4, 86.1, 88.7, 91.1,
    ],
  };

  // Baby's recorded measurements
  let measurements = $state<{ month: number; length: number }[]>([
    { month: 0, length: 55 },
    { month: 1, length: 58 },
    { month: 2, length: 61 },
  ]);

  // Input state
  let newMonth = $state(3);
  let newLength = $state(64);

  const estimation = $derived.by(() => {
    if (measurements.length < 2) return [];

    const n = measurements.length;
    const sumX = measurements.reduce((a, d) => a + d.month, 0);
    const sumY = measurements.reduce((a, d) => a + d.length, 0);
    const sumXY = measurements.reduce((a, d) => a + d.month * d.length, 0);
    const sumX2 = measurements.reduce((a, d) => a + d.month * d.month, 0);

    const slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    const intercept = (sumY - slope * sumX) / n;

    const lastMonth = measurements[measurements.length - 1].month;
    const points: { month: number; length: number }[] = [];

    for (let m = lastMonth; m <= 24; m += 1) {
      const ageAdjust = Math.max(0.4, 1 - (m - lastMonth) * 0.03);
      const estimatedLength =
        intercept + slope * m * ageAdjust + (1 - ageAdjust) * slope * lastMonth;
      points.push({ month: m, length: Math.max(0, estimatedLength) });
    }

    return points;
  });

  function addMeasurement() {
    if (newMonth >= 0 && newMonth <= 24 && newLength > 0) {
      measurements = [
        ...measurements,
        { month: newMonth, length: newLength },
      ].sort((a, b) => a.month - b.month);
      newMonth = Math.min(24, measurements[measurements.length - 1].month + 1);
    }
  }

  function removeMeasurement(index: number) {
    measurements = measurements.filter((_, i) => i !== index);
  }

  // Dress sizes (Italian/EU sizing)
  const dressSizes = [
    { name: "1-3", minLength: 55, maxLength: 56, color: "rgb(244, 114, 182)" }, // pink
    { name: "3-6", minLength: 56, maxLength: 62, color: "rgb(168, 85, 247)" }, // purple
    { name: "6-9", minLength: 62, maxLength: 68, color: "rgb(99, 102, 241)" }, // indigo
    { name: "9-12", minLength: 68, maxLength: 76, color: "rgb(59, 130, 246)" }, // blue
    { name: "12-18", minLength: 76, maxLength: 83, color: "rgb(20, 184, 166)" }, // teal
    { name: "18-24", minLength: 83, maxLength: 89, color: "rgb(132, 204, 22)" }, // lime
    { name: "24-36", minLength: 89, maxLength: 96, color: "rgb(245, 158, 11)" }, // amber
  ];

  // Get size for a given length
  function getSizeForLength(length: number) {
    for (const size of dressSizes) {
      if (length >= size.minLength && length < size.maxLength) {
        return size;
      }
    }
    if (length < dressSizes[0].minLength)
      return {
        name: "Under 9-12",
        minLength: 0,
        maxLength: dressSizes[0].minLength,
        color: "rgb(156, 163, 175)",
      };
    return dressSizes[dressSizes.length - 1];
  }

  // Get current size based on latest measurement
  const currentSize = $derived.by(() => {
    const lastMeasurement = measurements[measurements.length - 1];
    if (!lastMeasurement) return null;
    return getSizeForLength(lastMeasurement.length);
  });

  // Calculate when baby will reach each size based on projection
  const sizeProjections = $derived.by(() => {
    if (estimation.length < 2) return [];

    const projections: { size: (typeof dressSizes)[0]; month: number }[] = [];

    for (const size of dressSizes) {
      // Find the first month where baby reaches this size's minimum length
      const reachPoint = estimation.find((p) => p.length >= size.minLength);
      if (reachPoint) {
        projections.push({ size, month: reachPoint.month });
      }
    }

    return projections;
  });

  // Interpolate value from measurements/estimation at a given month
  function interpolateAt(
    data: { month: number; length: number }[],
    targetMonth: number,
  ): number | null {
    if (data.length === 0) return null;

    // Find surrounding points
    const before = data.filter((d) => d.month <= targetMonth).pop();
    const after = data.find((d) => d.month >= targetMonth);

    if (!before && !after) return null;
    if (!before) return after!.length;
    if (!after) return before.length;
    if (before.month === after.month) return before.length;

    // Linear interpolation
    const t = (targetMonth - before.month) / (after.month - before.month);
    return before.length + t * (after.length - before.length);
  }

  // Transform WHO data into chart format with baby data
  const growthChartData = $derived.by(() => {
    // Get all unique months from WHO data, measurements, and estimation
    const allMonths = new Set([
      ...whoPercentiles.months,
      ...measurements.map((m) => m.month),
      ...estimation.map((e) => e.month),
    ]);

    const sortedMonths = [...allMonths]
      .sort((a, b) => a - b)
      .filter((m) => m >= 0 && m <= 24);

    // Helper to interpolate WHO percentiles
    function interpolateWHO(
      key: keyof typeof whoPercentiles,
      month: number,
    ): number {
      const months = whoPercentiles.months;
      const values = whoPercentiles[key] as number[];

      const beforeIdx = months.findLastIndex((m) => m <= month);
      const afterIdx = months.findIndex((m) => m >= month);

      if (beforeIdx === -1) return values[0];
      if (afterIdx === -1) return values[values.length - 1];
      if (beforeIdx === afterIdx) return values[beforeIdx];

      const t =
        (month - months[beforeIdx]) / (months[afterIdx] - months[beforeIdx]);
      return values[beforeIdx] + t * (values[afterIdx] - values[beforeIdx]);
    }

    return sortedMonths.map((month) => {
      const babyValue = interpolateAt(measurements, month);
      const projValue = interpolateAt(estimation, month);

      return {
        month,
        p3: interpolateWHO("p3", month),
        p15: interpolateWHO("p15", month),
        p50: interpolateWHO("p50", month),
        p85: interpolateWHO("p85", month),
        p97: interpolateWHO("p97", month),
        baby: babyValue,
        projection: projValue,
      };
    });
  });

  type ChartDataPoint = {
    month: number;
    p3: number;
    p15: number;
    p50: number;
    p85: number;
    p97: number;
    baby: number | null;
    projection: number | null;
  };

  const chartColors = {
    p3: "hsl(var(--muted-foreground) / 0.3)",
    p15: "hsl(var(--muted-foreground) / 0.2)",
    p50: "hsl(var(--muted-foreground))",
    p85: "hsl(var(--muted-foreground) / 0.2)",
    p97: "hsl(var(--muted-foreground) / 0.3)",
    baby: "hsl(217 91% 60%)",
    projection: "hsl(142 71% 45%)",
  };

  const chartData = [
    { date: new Date("2024-04-01"), desktop: 222, mobile: 150 },
    { date: new Date("2024-04-02"), desktop: 97, mobile: 180 },
    { date: new Date("2024-04-03"), desktop: 167, mobile: 120 },
    { date: new Date("2024-04-04"), desktop: 242, mobile: 260 },
    { date: new Date("2024-04-05"), desktop: 373, mobile: 290 },
    { date: new Date("2024-04-06"), desktop: 301, mobile: 340 },
    { date: new Date("2024-04-07"), desktop: 245, mobile: 180 },
    { date: new Date("2024-04-08"), desktop: 409, mobile: 320 },
    { date: new Date("2024-04-09"), desktop: 59, mobile: 110 },
    { date: new Date("2024-04-10"), desktop: 261, mobile: 190 },
    { date: new Date("2024-04-11"), desktop: 327, mobile: 350 },
    { date: new Date("2024-04-12"), desktop: 292, mobile: 210 },
    { date: new Date("2024-04-13"), desktop: 342, mobile: 380 },
    { date: new Date("2024-04-14"), desktop: 137, mobile: 220 },
    { date: new Date("2024-04-15"), desktop: 120, mobile: 170 },
    { date: new Date("2024-04-16"), desktop: 138, mobile: 190 },
    { date: new Date("2024-04-17"), desktop: 446, mobile: 360 },
    { date: new Date("2024-04-18"), desktop: 364, mobile: 410 },
    { date: new Date("2024-04-19"), desktop: 243, mobile: 180 },
    { date: new Date("2024-04-20"), desktop: 89, mobile: 150 },
    { date: new Date("2024-04-21"), desktop: 137, mobile: 200 },
    { date: new Date("2024-04-22"), desktop: 224, mobile: 170 },
    { date: new Date("2024-04-23"), desktop: 138, mobile: 230 },
    { date: new Date("2024-04-24"), desktop: 387, mobile: 290 },
    { date: new Date("2024-04-25"), desktop: 215, mobile: 250 },
    { date: new Date("2024-04-26"), desktop: 75, mobile: 130 },
    { date: new Date("2024-04-27"), desktop: 383, mobile: 420 },
    { date: new Date("2024-04-28"), desktop: 122, mobile: 180 },
    { date: new Date("2024-04-29"), desktop: 315, mobile: 240 },
    { date: new Date("2024-04-30"), desktop: 454, mobile: 380 },
    { date: new Date("2024-05-01"), desktop: 165, mobile: 220 },
    { date: new Date("2024-05-02"), desktop: 293, mobile: 310 },
    { date: new Date("2024-05-03"), desktop: 247, mobile: 190 },
    { date: new Date("2024-05-04"), desktop: 385, mobile: 420 },
    { date: new Date("2024-05-05"), desktop: 481, mobile: 390 },
    { date: new Date("2024-05-06"), desktop: 498, mobile: 520 },
    { date: new Date("2024-05-07"), desktop: 388, mobile: 300 },
    { date: new Date("2024-05-08"), desktop: 149, mobile: 210 },
    { date: new Date("2024-05-09"), desktop: 227, mobile: 180 },
    { date: new Date("2024-05-10"), desktop: 293, mobile: 330 },
    { date: new Date("2024-05-11"), desktop: 335, mobile: 270 },
    { date: new Date("2024-05-12"), desktop: 197, mobile: 240 },
    { date: new Date("2024-05-13"), desktop: 197, mobile: 160 },
    { date: new Date("2024-05-14"), desktop: 448, mobile: 490 },
    { date: new Date("2024-05-15"), desktop: 473, mobile: 380 },
    { date: new Date("2024-05-16"), desktop: 338, mobile: 400 },
    { date: new Date("2024-05-17"), desktop: 499, mobile: 420 },
    { date: new Date("2024-05-18"), desktop: 315, mobile: 350 },
    { date: new Date("2024-05-19"), desktop: 235, mobile: 180 },
    { date: new Date("2024-05-20"), desktop: 177, mobile: 230 },
    { date: new Date("2024-05-21"), desktop: 82, mobile: 140 },
    { date: new Date("2024-05-22"), desktop: 81, mobile: 120 },
    { date: new Date("2024-05-23"), desktop: 252, mobile: 290 },
    { date: new Date("2024-05-24"), desktop: 294, mobile: 220 },
    { date: new Date("2024-05-25"), desktop: 201, mobile: 250 },
    { date: new Date("2024-05-26"), desktop: 213, mobile: 170 },
    { date: new Date("2024-05-27"), desktop: 420, mobile: 460 },
    { date: new Date("2024-05-28"), desktop: 233, mobile: 190 },
    { date: new Date("2024-05-29"), desktop: 78, mobile: 130 },
    { date: new Date("2024-05-30"), desktop: 340, mobile: 280 },
    { date: new Date("2024-05-31"), desktop: 178, mobile: 230 },
    { date: new Date("2024-06-01"), desktop: 178, mobile: 200 },
    { date: new Date("2024-06-02"), desktop: 470, mobile: 410 },
    { date: new Date("2024-06-03"), desktop: 103, mobile: 160 },
    { date: new Date("2024-06-04"), desktop: 439, mobile: 380 },
    { date: new Date("2024-06-05"), desktop: 88, mobile: 140 },
    { date: new Date("2024-06-06"), desktop: 294, mobile: 250 },
    { date: new Date("2024-06-07"), desktop: 323, mobile: 370 },
    { date: new Date("2024-06-08"), desktop: 385, mobile: 320 },
    { date: new Date("2024-06-09"), desktop: 438, mobile: 480 },
    { date: new Date("2024-06-10"), desktop: 155, mobile: 200 },
    { date: new Date("2024-06-11"), desktop: 92, mobile: 150 },
    { date: new Date("2024-06-12"), desktop: 492, mobile: 420 },
    { date: new Date("2024-06-13"), desktop: 81, mobile: 130 },
    { date: new Date("2024-06-14"), desktop: 426, mobile: 380 },
    { date: new Date("2024-06-15"), desktop: 307, mobile: 350 },
    { date: new Date("2024-06-16"), desktop: 371, mobile: 310 },
    { date: new Date("2024-06-17"), desktop: 475, mobile: 520 },
    { date: new Date("2024-06-18"), desktop: 107, mobile: 170 },
    { date: new Date("2024-06-19"), desktop: 341, mobile: 290 },
    { date: new Date("2024-06-20"), desktop: 408, mobile: 450 },
    { date: new Date("2024-06-21"), desktop: 169, mobile: 210 },
    { date: new Date("2024-06-22"), desktop: 317, mobile: 270 },
    { date: new Date("2024-06-23"), desktop: 480, mobile: 530 },
    { date: new Date("2024-06-24"), desktop: 132, mobile: 180 },
    { date: new Date("2024-06-25"), desktop: 141, mobile: 190 },
    { date: new Date("2024-06-26"), desktop: 434, mobile: 380 },
    { date: new Date("2024-06-27"), desktop: 448, mobile: 490 },
    { date: new Date("2024-06-28"), desktop: 149, mobile: 200 },
    { date: new Date("2024-06-29"), desktop: 103, mobile: 160 },
    { date: new Date("2024-06-30"), desktop: 446, mobile: 400 },
  ];

  let timeRange = $state("90d");

  const selectedLabel = $derived.by(() => {
    switch (timeRange) {
      case "90d":
        return "Last 3 months";
      case "30d":
        return "Last 30 days";
      case "7d":
        return "Last 7 days";
      default:
        return "Last 3 months";
    }
  });

  const filteredData = $derived(
    chartData.filter((item) => {
      // eslint-disable-next-line svelte/prefer-svelte-reactivity
      const referenceDate = new Date("2024-06-30");
      let daysToSubtract = 90;
      if (timeRange === "30d") {
        daysToSubtract = 30;
      } else if (timeRange === "7d") {
        daysToSubtract = 7;
      }

      referenceDate.setDate(referenceDate.getDate() - daysToSubtract);
      return item.date >= referenceDate;
    }),
  );

  const chartConfig = {
    desktop: { label: "Desktop", color: "var(--chart-1)" },
    mobile: { label: "Mobile", color: "var(--chart-2)" },
  } satisfies Chart.ChartConfig;
</script>

<div class="w-full max-w-4xl mx-auto p-4">
  <!-- Age & Size Header -->
  <div
    class="mb-6 p-6 rounded-xl bg-linear-to-r from-blue-500 to-purple-500 text-white"
  >
    <div class="flex flex-wrap items-center justify-between gap-4">
      <div>
        <div class="text-sm opacity-80">Current Age</div>
        <div class="text-3xl font-bold">{Math.floor(currentMonth)} months</div>
        <div class="text-sm opacity-80">
          {getFullCalendarMonth(currentMonth)} 2026
        </div>
      </div>
      {#if currentSize}
        <div class="text-right">
          <div class="text-sm opacity-80">Current Size</div>
          <div class="text-3xl font-bold">Taglia {currentSize.name}</div>
          <div class="text-sm opacity-80">
            {measurements[measurements.length - 1]?.length} cm
          </div>
        </div>
      {/if}
    </div>
  </div>

  <Card.Root>
    <Card.Header
      class="flex items-center gap-2 space-y-0 border-b py-5 sm:flex-row"
    >
      <div class="grid flex-1 gap-1 text-center sm:text-start">
        <Card.Title>Area Chart - Interactive</Card.Title>
        <Card.Description
          >Showing total visitors for the last 3 months</Card.Description
        >
      </div>
    </Card.Header>
    <Card.Content>
      <Chart.Container
        config={chartConfig}
        class="-ml-3 aspect-auto h-[250px] w-full"
      >
        <AreaChart
          legend
          data={filteredData}
          x="date"
          xScale={scaleUtc()}
          series={[
            {
              key: "mobile",
              label: "Mobile",
              color: chartConfig.mobile.color,
            },
            {
              key: "desktop",
              label: "Desktop",
              color: chartConfig.desktop.color,
            },
          ]}
          seriesLayout="stack"
          props={{
            area: {
              curve: curveNatural,
              "fill-opacity": 0.4,
              line: { class: "stroke-1" },
              motion: "tween",
            },
            xAxis: {
              ticks: timeRange === "7d" ? 7 : undefined,
              format: (v) => {
                return v.toLocaleDateString("en-US", {
                  month: "short",
                  day: "numeric",
                });
              },
            },

            yAxis: { format: () => "" },
          }}
        >
          {#snippet marks({ series, getAreaProps })}
            <defs>
              <linearGradient id="fillDesktop" x1="0" y1="0" x2="0" y2="1">
                <stop
                  offset="5%"
                  stop-color="var(--color-desktop)"
                  stop-opacity={1.0}
                />
                <stop
                  offset="95%"
                  stop-color="var(--color-desktop)"
                  stop-opacity={0.1}
                />
              </linearGradient>
              <linearGradient id="fillMobile" x1="0" y1="0" x2="0" y2="1">
                <stop
                  offset="5%"
                  stop-color="var(--color-mobile)"
                  stop-opacity={0.8}
                />
                <stop
                  offset="95%"
                  stop-color="var(--color-mobile)"
                  stop-opacity={0.1}
                />
              </linearGradient>
            </defs>
            <ChartClipPath
              initialWidth={0}
              motion={{
                width: { type: "tween", duration: 1000, easing: cubicInOut },
              }}
            >
              {#each series as s, i (s.key)}
                <Area
                  {...getAreaProps(s, i)}
                  fill={s.key === "desktop"
                    ? "url(#fillDesktop)"
                    : "url(#fillMobile)"}
                />
              {/each}
            </ChartClipPath>
          {/snippet}
          {#snippet tooltip()}
            <Chart.Tooltip
              labelFormatter={(v: Date) => {
                return v.toLocaleDateString("en-US", {
                  month: "long",
                });
              }}
              indicator="line"
            />
          {/snippet}
        </AreaChart>
      </Chart.Container>
    </Card.Content>
  </Card.Root>

  <!-- Dress Size Estimation -->
  <Card.Root class="mt-6">
    <Card.Header>
      <Card.Title class="text-lg">Dress Size Estimation</Card.Title>
      <Card.Description
        >Based on current measurements and growth projection</Card.Description
      >
    </Card.Header>
    <Card.Content>
      <div class="grid gap-4 sm:grid-cols-2">
        <!-- Current Size -->
        <div class="p-4 rounded-lg bg-muted">
          <div class="text-sm text-muted-foreground mb-1">Current Size</div>
          {#if currentSize}
            <div class="text-2xl font-bold" style="color: {currentSize.color}">
              Taglia {currentSize.name}
            </div>
            <div class="text-sm text-muted-foreground mt-1">
              {measurements[measurements.length - 1]?.length} cm at month {measurements[
                measurements.length - 1
              ]?.month}
            </div>
          {:else}
            <div class="text-muted-foreground">No measurements</div>
          {/if}
        </div>

        <!-- Size Projections -->
        <div class="p-4 rounded-lg bg-muted">
          <div class="text-sm text-muted-foreground mb-2">
            Projected Size Changes
          </div>
          {#if sizeProjections.length > 0}
            <div class="space-y-2">
              {#each sizeProjections.filter((p) => p.month > measurements[measurements.length - 1]?.month) as proj (proj.size.name)}
                <div class="flex items-center justify-between text-sm">
                  <span class="font-medium" style="color: {proj.size.color}"
                    >Taglia {proj.size.name}</span
                  >
                  <span class="text-muted-foreground"
                    >~ month {proj.month} ({getCalendarMonth(proj.month)})</span
                  >
                </div>
              {/each}
              {#if sizeProjections.filter((p) => p.month > measurements[measurements.length - 1]?.month).length === 0}
                <div class="text-sm text-muted-foreground">
                  Add more measurements for projections
                </div>
              {/if}
            </div>
          {:else}
            <div class="text-sm text-muted-foreground">
              Add more measurements for projections
            </div>
          {/if}
        </div>
      </div>

      <!-- Size Reference -->
      <div class="mt-4 pt-4 border-t">
        <div class="text-sm text-muted-foreground mb-2">Size Reference</div>
        <div class="flex flex-wrap gap-3">
          {#each dressSizes as size (size.name)}
            <div class="flex items-center gap-2 text-sm">
              <div
                class="w-3 h-3 rounded"
                style="background-color: {size.color}; opacity: 0.7"
              ></div>
              <span
                ><strong>{size.name}</strong>: {size.minLength}-{size.maxLength}
                cm</span
              >
            </div>
          {/each}
        </div>
      </div>
    </Card.Content>
  </Card.Root>

  <!-- Controls -->
  <Card.Root class="mt-6">
    <Card.Header>
      <Card.Title class="text-lg">Add Measurement</Card.Title>
    </Card.Header>
    <Card.Content>
      <div class="flex flex-wrap gap-4 items-end">
        <label class="flex flex-col gap-1.5">
          <span class="text-sm text-muted-foreground">Month</span>
          <input
            type="number"
            bind:value={newMonth}
            min="0"
            max="24"
            step="1"
            class="w-24 px-3 py-2 border border-input rounded-md bg-background focus:outline-none focus:ring-2 focus:ring-ring"
          />
        </label>
        <label class="flex flex-col gap-1.5">
          <span class="text-sm text-muted-foreground">Length (cm)</span>
          <input
            type="number"
            bind:value={newLength}
            min="0"
            max="100"
            step="0.5"
            class="w-24 px-3 py-2 border border-input rounded-md bg-background focus:outline-none focus:ring-2 focus:ring-ring"
          />
        </label>
        <button
          onclick={addMeasurement}
          class="px-4 py-2 bg-primary text-primary-foreground rounded-md hover:bg-primary/90 transition-colors font-medium"
        >
          Add
        </button>
      </div>

      <div class="mt-6">
        <h4 class="text-sm font-medium mb-3">Recorded Measurements</h4>
        <div class="flex flex-wrap gap-2">
          {#each measurements as m, i (m.month)}
            <div
              class="flex items-center gap-2 px-3 py-1.5 bg-muted rounded-md text-sm"
            >
              <span>Month {m.month}: {m.length} cm</span>
              <button
                onclick={() => removeMeasurement(i)}
                class="w-5 h-5 flex items-center justify-center rounded text-muted-foreground hover:bg-destructive hover:text-destructive-foreground transition-colors"
              >
                ×
              </button>
            </div>
          {/each}
        </div>
      </div>
    </Card.Content>
  </Card.Root>
</div>
