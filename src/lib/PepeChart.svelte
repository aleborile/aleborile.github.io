<script lang="ts">
  import { LineChart } from "layerchart";
  import { scaleUtc, tickFormat } from "d3-scale";
  import { curveNatural } from "d3-shape";
  import * as Chart from "$lib/components/ui/chart/index.js";
  import * as Card from "$lib/components/ui/card/index.js";
  import { add as addDate } from "date-fns";
  import { MediaQuery } from "svelte/reactivity";
  import { mode, toggleMode, setMode } from "mode-watcher";

  const isMobile = new MediaQuery("(max-width: 640px)");

  const birthDate = new Date("2025-12-11");

  // Calculate current age in months and days
  const currentAge = $derived.by(() => {
    const now = new Date();
    let months =
      (now.getFullYear() - birthDate.getFullYear()) * 12 +
      (now.getMonth() - birthDate.getMonth());
    let days = now.getDate() - birthDate.getDate();
    if (days < 0) {
      months--;
      const prevMonth = new Date(now.getFullYear(), now.getMonth(), 0);
      days += prevMonth.getDate();
    }
    return { months, days };
  });

  const currentMonth = $derived(currentAge.months + currentAge.days / 30);

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

  const measurements = [
    { month: 0, length: 55 },
    { month: 1, length: 58 },
    { month: 2, length: 62 },
  ];

  // Dress sizes (Italian/EU sizing)
  const dressSizes = [
    { name: "1-3", minLength: 55, maxLength: 56 },
    { name: "3-6", minLength: 56, maxLength: 62 },
    { name: "6-9", minLength: 62, maxLength: 68 },
    { name: "9-12", minLength: 68, maxLength: 76 },
    { name: "12-18", minLength: 76, maxLength: 83 },
    { name: "18-24", minLength: 83, maxLength: 89 },
    { name: "24-36", minLength: 89, maxLength: 96 },
  ];

  function getSizeForLength(length: number): string {
    for (const size of dressSizes) {
      if (length >= size.minLength && length < size.maxLength) {
        return size.name;
      }
    }
    if (length < dressSizes[0].minLength) return "Under 1-3";
    return dressSizes[dressSizes.length - 1].name;
  }

  // Get current size based on latest measurement
  const currentSize = $derived.by(() => {
    const lastMeasurement = measurements[measurements.length - 1];
    if (!lastMeasurement) return null;
    return getSizeForLength(lastMeasurement.length);
  });

  const currentLength = $derived.by(() => {
    if (measurements.length === 0) return null;
    if (measurements.length === 1) return measurements[0].length;

    // Sort measurements by month to ensure order
    const sorted = [...measurements].sort((a, b) => a.month - b.month);

    // If before first measurement, return first value
    if (currentMonth <= sorted[0].month) return sorted[0].length;

    // If after last measurement, extrapolate using last two measurements
    const last = sorted[sorted.length - 1];
    if (currentMonth >= last.month) {
      const prev = sorted[sorted.length - 2];
      const slope = (last.length - prev.length) / (last.month - prev.month);
      return last.length + slope * (currentMonth - last.month);
    }

    // Find bracketing measurements and interpolate
    for (let i = 0; i < sorted.length - 1; i++) {
      if (
        currentMonth >= sorted[i].month &&
        currentMonth < sorted[i + 1].month
      ) {
        const m1 = sorted[i];
        const m2 = sorted[i + 1];
        const t = (currentMonth - m1.month) / (m2.month - m1.month);
        return m1.length + t * (m2.length - m1.length);
      }
    }

    return null;
  });

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
    const points: { date: Date; month: number; length: number }[] = [];

    // Start from month 0, use real measurements when available
    for (let m = 0; m <= 24; m += 1) {
      const measurement = measurements.find((mes) => mes.month === m);
      let length: number;

      if (measurement) {
        // Use actual measurement
        length = measurement.length;
      } else {
        // Use estimation with age adjustment for future months
        const ageAdjust = Math.max(0.4, 1 - (m - lastMonth) * 0.03);
        length = Math.max(
          0,
          intercept +
            slope * m * ageAdjust +
            (1 - ageAdjust) * slope * lastMonth,
        );
      }

      points.push({
        date: addDate(birthDate, { months: m }),
        month: m,
        length,
      });
    }

    return points;
  });

  // All months data for the list
  const allMonthsData = $derived.by(() =>
    Array.from(Array(24), (_, i) => i).map((month) => {
      const measurementLength = measurements.find(
        (m) => m.month === month,
      )?.length;
      const estimateLength = estimation.find((e) => e.month === month)?.length;
      const lengthForSize = measurementLength ?? estimateLength;
      return {
        idx: month,
        date: addDate(birthDate, { months: month }),
        length: measurementLength,
        estimate: estimateLength,
        dressSize: lengthForSize ? getSizeForLength(lengthForSize) : undefined,
      };
    }),
  );

  // Filtered data for chart (every 3 months on mobile)
  const chartData = $derived.by(() => {
    const step = isMobile.current ? 3 : 1;
    return allMonthsData.filter((d) => d.idx % step === 0);
  });

  const chartConfig = $derived({
    length: { label: "length", color: mode.current === 'dark' ? "#f87171" : "red" },
    estimate: { label: "estimate", color: mode.current === 'dark' ? "#4ade80" : "green" },
  } satisfies Chart.ChartConfig);
</script>

<svelte:head>
  <title>Pepé Chart</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link
    rel="preconnect"
    href="https://fonts.gstatic.com"
    crossorigin="anonymous"
  />
  <link
    href="https://fonts.googleapis.com/css2?family=Great+Vibes&display=swap"
    rel="stylesheet"
  />
</svelte:head>

<!-- Age & Size Header -->
<div
  class="mb-6 p-6 rounded-xl bg-linear-to-r from-blue-400 to-blue-600 dark:from-blue-800 dark:to-blue-950 text-white relative overflow-hidden"
>
  <!-- Background overlay -->
  {#if mode.current === 'dark'}
    <div class="absolute inset-0 pointer-events-none select-none">
      <span class="absolute top-2 left-[10%] text-xs opacity-60">✦</span>
      <span class="absolute top-4 left-[25%] text-[0.5rem] opacity-40">✦</span>
      <span class="absolute top-1 left-[40%] text-sm opacity-50">✦</span>
      <span class="absolute top-5 left-[55%] text-[0.4rem] opacity-30">✦</span>
      <span class="absolute top-2 left-[70%] text-xs opacity-50">✦</span>
      <span class="absolute top-6 left-[15%] text-[0.5rem] opacity-35">✦</span>
      <span class="absolute top-3 left-[85%] text-[0.4rem] opacity-45">✦</span>
      <span class="absolute bottom-8 left-[20%] text-[0.5rem] opacity-40">✦</span>
      <span class="absolute bottom-6 left-[45%] text-xs opacity-35">✦</span>
      <span class="absolute bottom-10 left-[65%] text-[0.4rem] opacity-50">✦</span>
      <span class="absolute bottom-4 left-[30%] text-[0.5rem] opacity-30">✦</span>
      <span class="absolute top-4 right-12 text-7xl opacity-80">🌙</span>
    </div>
  {:else}
    <div class="absolute inset-0 pointer-events-none select-none">
      <span class="absolute top-2 left-[5%] text-3xl opacity-30">☁️</span>
      <span class="absolute top-6 left-[25%] text-2xl opacity-25">☁️</span>
      <span class="absolute bottom-6 left-[15%] text-4xl opacity-20">☁️</span>
      <span class="absolute top-4 left-[50%] text-2xl opacity-25">☁️</span>
      <span class="absolute bottom-8 left-[60%] text-3xl opacity-20">☁️</span>
      <span class="absolute top-4 right-12 text-7xl opacity-80">☀️</span>
    </div>
  {/if}
  <span class="absolute top-3 left-3 text-3xl">🍼</span>
  <button
    onclick={() => toggleMode()}
    class="absolute top-3 right-3 text-3xl cursor-pointer hover:scale-110 transition-transform"
    >{mode.current === "dark" ? "👶" : "😎"}</button
  >
  <div class="text-center mb-4">
    <span class="text-5xl md:text-7xl" style="font-family: 'Great Vibes', cursive;"
      >Pepé</span
    >
  </div>
  <div class="flex flex-wrap items-center justify-between gap-2 sm:gap-4">
    <div>
      <div class="text-xs sm:text-sm opacity-80">Current Age</div>
      <div class="text-lg sm:text-3xl font-bold">
        {currentAge.months} months and {currentAge.days}
        {currentAge.days === 1 ? "day" : "days"}
      </div>
      <div class="text-xs sm:text-sm opacity-80">
        {new Date().getDate()}
        {getFullCalendarMonth(currentMonth)} 2026
      </div>
    </div>
    {#if currentLength}
      <div class="text-right">
        <div class="text-xs sm:text-sm opacity-80">Current Length</div>
        <div class="text-lg sm:text-3xl font-bold">
          {currentLength.toFixed(1)} cm
        </div>
        <div class="text-xs sm:text-sm opacity-80">
          Taglia {currentSize}
        </div>
      </div>
    {/if}
  </div>
</div>

<Card.Root class="bg-gray-800">
  <Card.Header>
    <Card.Title class="dark:text-white">Pepé Chart</Card.Title>
    <Card.Description class="dark:text-gray-300">Growth estimation with dress sizes</Card.Description>
  </Card.Header>
  <Card.Content>
    <Chart.Container config={chartConfig}>
      <LineChart
        points={{ r: 4 }}
        labels={{ offset: 10}}
        data={chartData}
        grid={{ y: true, x: true }}
        x="date"
        axis="x"
        xScale={scaleUtc()}
        series={[
          {
            key: "estimate",
            label: "estimate",
            color: chartConfig.estimate.color,
          },
          {
            key: "length",
            label: "length",
            color: chartConfig.length.color,
          },
        ]}
        props={{
          spline: { curve: curveNatural, motion: "tween", strokeWidth: 2 },
          highlight: {
            points: {
              motion: "spring",
              r: 6,
            },
          },
          xAxis: {
            format: (v: Date) =>
              v.toLocaleDateString("it-IT", {
                month: "short",
                year: "2-digit",
              }),
          },
          points: { r: 4 },
        }}
      >
        {#snippet tooltip()}
          <Chart.Tooltip
            labelFormatter={(v: Date) => {
              return v.toLocaleDateString("en-US", {
                month: "long",
                year: "2-digit",
              });
            }}
            indicator="line"
          >
            {#snippet formatter({
              value,
              name,
              item,
            }: {
              value: unknown;
              name: string;
              item: { payload?: { dressSize?: string } };
            })}
              <div class="flex flex-1 justify-between items-center gap-2">
                <span class="text-muted-foreground">{name}</span>
                <span class="font-mono font-medium">
                  {typeof value === "number" ? value.toFixed(1) : value} cm
                </span>
              </div>
              {#if item.payload?.dressSize}
                <div class="text-muted-foreground text-xs mt-1">
                  Taglia {item.payload.dressSize}
                </div>
              {/if}
            {/snippet}
          </Chart.Tooltip>
        {/snippet}
      </LineChart>
    </Chart.Container>
  </Card.Content>
  <Card.Footer>
    <div class="flex w-full items-start gap-2 text-sm">
      <div class="grid gap-2">
        <div class="text-muted-foreground flex items-center gap-2 leading-none">
          {measurements.length} measurements recorded
        </div>
      </div>
    </div>
  </Card.Footer>
</Card.Root>

<!-- Monthly Growth Details -->
<Card.Root class="mt-6 dark:bg-gray-800">
  <Card.Header>
    <Card.Title class="dark:text-white">Monthly Growth Details</Card.Title>
    <Card.Description class="dark:text-gray-300"
      >Estimated growth with dress sizes by month</Card.Description
    >
  </Card.Header>
  <Card.Content>
    <div class="grid gap-2">
      {#each allMonthsData as data (data.idx)}
        {#if data.estimate || data.length}
          <div
            class="flex items-center justify-between p-3 rounded-lg bg-gray-100 hover:bg-gray-200 dark:bg-gray-700 dark:hover:bg-gray-700 transition-colors {data.idx ===
            Math.floor(currentMonth)
              ? 'ring-2 ring-red-500 bg-red-50 dark:bg-red-950/30'
              : ''}"
          >
            <div class="flex items-center gap-3">
              <span
                class="text-xs px-2 py-0.5 rounded-full bg-gray-300 dark:bg-gray-600 font-mono text-gray-700 dark:text-gray-200"
                >{data.idx}</span
              >
              <span class="text-sm font-bold text-gray-900 dark:text-gray-100">
                {data.date.toLocaleDateString("en-US", {
                  month: "short",
                  year: "2-digit",
                })}
              </span>
            </div>
            <div class="flex items-center gap-4">
              {#if data.length}
                <div class="flex items-center gap-2">
                  <span class="w-2 h-2 rounded-full bg-red-500"></span>
                  <span class="text-sm font-mono text-gray-900 dark:text-gray-100">{data.length} cm</span>
                </div>
              {/if}
              {#if data.estimate}
                <div class="flex items-center gap-2">
                  <span class="w-2 h-2 rounded-full bg-green-500"></span>
                  <span class="text-sm font-mono text-gray-900 dark:text-gray-100"
                    >{data.estimate.toFixed(1)} cm</span
                  >
                </div>
              {/if}
              {#if data.dressSize}
                <div
                  class="text-xs px-2 py-1 rounded bg-blue-100 dark:bg-blue-900 text-blue-700 dark:text-blue-200 font-medium"
                >
                  Taglia {data.dressSize}
                </div>
              {/if}
            </div>
          </div>
        {/if}
      {/each}
    </div>
  </Card.Content>
</Card.Root>
