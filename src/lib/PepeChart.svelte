<script lang="ts">
  import { LineChart } from "layerchart";
  import { scaleUtc } from "d3-scale";
  import { curveNatural } from "d3-shape";
  import * as Chart from "$lib/components/ui/chart/index.js";
  import * as Card from "$lib/components/ui/card/index.js";
  import { add as addDate } from "date-fns";

  const birthDate = new Date("2025-12-11");

  // Calculate current month based on browser's current date
  const currentMonth = $derived.by(() => {
    const now = new Date();
    const diffMs = now.getTime() - birthDate.getTime();
    const diffDays = diffMs / (1000 * 60 * 60 * 24);
    return diffDays / 30.44;
  });

  function getFullCalendarMonth(chartMonth: number): string {
    const months = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December",
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

    for (let m = lastMonth; m <= 24; m += 1) {
      const ageAdjust = Math.max(0.4, 1 - (m - lastMonth) * 0.03);
      const estimatedLength =
        intercept + slope * m * ageAdjust + (1 - ageAdjust) * slope * lastMonth;
      points.push({
        date: addDate(birthDate, { months: m }),
        month: m,
        length: Math.max(0, estimatedLength),
      });
    }

    return points;
  });

  const chartData = $derived.by(() =>
    Array.from(Array(24), (_, i) => i).map((month) => {
      const measurementLength = measurements.find((m) => m.month === month)?.length;
      const estimateLength = estimation.find((e) => e.month === month)?.length;
      const lengthForSize = measurementLength ?? estimateLength;
      return {
        date: addDate(birthDate, { months: month }),
        length: measurementLength,
        estimate: estimateLength,
        dressSize: lengthForSize ? getSizeForLength(lengthForSize) : undefined,
      };
    }),
  );

  const chartConfig = {
    length: { label: "length", color: "red" },
    estimate: { label: "estimate", color: "green" },
  } satisfies Chart.ChartConfig;
</script>

<!-- Age & Size Header -->
<div class="mb-6 p-6 rounded-xl bg-linear-to-r from-blue-500 to-purple-500 text-white">
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
        <div class="text-3xl font-bold">Taglia {currentSize}</div>
        <div class="text-sm opacity-80">
          {measurements[measurements.length - 1]?.length} cm
        </div>
      </div>
    {/if}
  </div>
</div>

<Card.Root>
  <Card.Header>
    <Card.Title>Pepe Chart</Card.Title>
    <Card.Description>Growth estimation with dress sizes</Card.Description>
  </Card.Header>
  <Card.Content>
    <Chart.Container config={chartConfig}>
      <LineChart
        points={{ r: 4 }}
        labels={{ offset: 12 }}
        data={chartData}
        x="date"
        axis="x"
        xScale={scaleUtc()}
        series={[
          {
            key: "length",
            label: "length",
            color: chartConfig.length.color,
          },
          {
            key: "estimate",
            label: "estimate",
            color: chartConfig.estimate.color,
          },
        ]}
        props={{
          spline: { curve: curveNatural, motion: "tween", strokeWidth: 2 },
          highlight: {
            points: {
              motion: "none",
              r: 6,
            },
          },
          xAxis: {
            format: (v: Date) =>
              v.toLocaleDateString("en-US", { month: "short" }),
          },
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
            {#snippet formatter({ value, name, item }: { value: unknown; name: string; item: { payload?: { dressSize?: string } } })}
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
<Card.Root class="mt-6">
  <Card.Header>
    <Card.Title>Monthly Growth Details</Card.Title>
    <Card.Description>Estimated growth with dress sizes by month</Card.Description>
  </Card.Header>
  <Card.Content>
    <div class="grid gap-2">
      {#each chartData as data, i (i)}
        {#if data.estimate || data.length}
          <div class="flex items-center justify-between p-3 rounded-lg bg-muted/50 hover:bg-muted transition-colors">
            <div class="flex items-center gap-3">
              <div class="text-sm font-medium w-20">
                {data.date.toLocaleDateString("en-US", { month: "short", year: "2-digit" })}
              </div>
              <div class="text-xs text-muted-foreground">
                Month {i}
              </div>
            </div>
            <div class="flex items-center gap-4">
              {#if data.length}
                <div class="flex items-center gap-2">
                  <span class="w-2 h-2 rounded-full bg-red-500"></span>
                  <span class="text-sm font-mono">{data.length} cm</span>
                </div>
              {/if}
              {#if data.estimate}
                <div class="flex items-center gap-2">
                  <span class="w-2 h-2 rounded-full bg-green-500"></span>
                  <span class="text-sm font-mono">{data.estimate.toFixed(1)} cm</span>
                </div>
              {/if}
              {#if data.dressSize}
                <div class="text-xs px-2 py-1 rounded bg-primary/10 text-primary font-medium">
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
